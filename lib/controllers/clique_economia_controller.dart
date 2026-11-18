import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../data/clique_economia_quote.dart';

class CliqueEconomiaController extends ChangeNotifier {
  CliqueEconomiaController({HttpClient? httpClient})
      : _httpClient = httpClient ?? HttpClient();

  static const _host = 'dadosabertos.c3sl.ufpr.br';
  static const _directory = '/curitiba/CliqueEconomia/';
  static final _quoteFilePattern = RegExp(
    r'(\d{4}-\d{2}-\d{2}_Clique_Economia_-_Cotacoes_-_Base_de_Dados\.csv)',
  );

  final HttpClient _httpClient;
  List<CliqueEconomiaProduct> _products = [];
  List<CliqueEconomiaProduct> visibleProducts = [];
  String? sourceFile;
  String? errorMessage;
  String query = '';
  bool isLoading = false;
  bool _isDisposed = false;

  int get productCount => _products.length;

  Future<void> loadLatest() async {
    if (isLoading) return;
    isLoading = true;
    errorMessage = null;
    _notifyListenersIfActive();

    try {
      final listing = await _getText(_directory);
      final fileNames = _quoteFilePattern
          .allMatches(listing)
          .map((match) => match.group(1)!)
          .toSet()
          .toList()
        ..sort((a, b) => b.compareTo(a));
      if (fileNames.isEmpty) {
        throw const FormatException('Nenhum arquivo de cotações foi encontrado.');
      }

      Object? lastFailure;
      for (final fileName in fileNames.take(5)) {
        try {
          final csv = await _getText('$_directory$fileName');
          final parsedProducts = _parseProducts(csv);
          if (parsedProducts.isEmpty) {
            throw const FormatException('O arquivo de cotações não contém registros.');
          }
          _products = parsedProducts;
          sourceFile = fileName;
          _applyFilter();
          lastFailure = null;
          break;
        } catch (error) {
          lastFailure = error;
        }
      }
      if (lastFailure != null) throw lastFailure;
    } on TimeoutException {
      errorMessage = 'A conexão demorou demais. Verifique sua internet e tente novamente.';
    } on SocketException {
      errorMessage = 'Não foi possível conectar aos Dados Abertos de Curitiba.';
    } on FormatException catch (error) {
      errorMessage = error.message;
    } catch (_) {
      errorMessage = 'Não foi possível carregar as cotações. Tente novamente.';
    } finally {
      isLoading = false;
      _notifyListenersIfActive();
    }
  }

  void setQuery(String value) {
    query = value;
    _applyFilter();
    _notifyListenersIfActive();
  }

  void _applyFilter() {
    final normalizedQuery = _normalize(query.trim());
    final matches = _products.where((product) {
      if (normalizedQuery.isEmpty) return true;
      return _normalize('${product.description} ${product.id}')
          .contains(normalizedQuery);
    }).toList()
      ..sort((a, b) {
        final aPrice = a.lowestPrice;
        final bPrice = b.lowestPrice;
        if (aPrice == 0) return 1;
        if (bPrice == 0) return -1;
        return aPrice.compareTo(bPrice);
      });
    visibleProducts = matches;
  }

  Future<String> _getText(String path) async {
    final request = await _httpClient
        .getUrl(Uri.https(_host, path))
        .timeout(const Duration(seconds: 20));
    request.headers.set(HttpHeaders.userAgentHeader, 'Prateleira/1.0.0');
    final response = await request.close().timeout(const Duration(seconds: 30));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException('HTTP ${response.statusCode}', uri: request.uri);
    }
    final bytes = await response.fold<List<int>>(
      <int>[],
      (buffer, chunk) => buffer..addAll(chunk),
    ).timeout(const Duration(seconds: 30));
    return utf8.decode(bytes, allowMalformed: true);
  }

  List<CliqueEconomiaProduct> _parseProducts(String csv) {
    final lines = _parseCsv(csv);
    if (lines.length < 2) return [];
    final header = lines.first.map((value) => value.trim().toLowerCase()).toList();
    final columns = [
      'data_pesquisa',
      'id_empresa',
      'rede',
      'endereco_completo',
      'codigo_categoria',
      'id_produto',
      'descricao',
      'preco_regular',
      'preco_atacado',
      'preco_atacado_qtd',
      'preco_promocao',
      'preco_fidelidade',
    ];
    final indexes = columns.map(header.indexOf).toList();
    if (indexes.any((index) => index < 0)) {
      throw const FormatException('As colunas do arquivo de cotações mudaram.');
    }

    final productsByKey = <String, CliqueEconomiaProduct>{};
    for (final rawRow in lines.skip(1)) {
      if (rawRow.every((value) => value.trim().isEmpty)) continue;
      final row = indexes
          .map((index) => index < rawRow.length ? rawRow[index] : '')
          .toList();
      final quote = CliqueEconomiaQuote.fromCsvRow(row);
      if (quote.description.isEmpty) continue;
      final key = '${quote.productId}|${quote.description.toLowerCase()}';
      final product = productsByKey.putIfAbsent(
        key,
        () => CliqueEconomiaProduct(
          id: quote.productId,
          description: quote.description,
        ),
      );
      product.quotes.add(quote);
    }
    return productsByKey.values.toList();
  }

  List<List<String>> _parseCsv(String content) {
    final firstLineEnd = content.indexOf('\n');
    final firstLine = firstLineEnd < 0 ? content : content.substring(0, firstLineEnd);
    final separator = firstLine.split(';').length > firstLine.split(',').length ? ';' : ',';
    final rows = <List<String>>[];
    var row = <String>[];
    final field = StringBuffer();
    var inQuotes = false;

    for (var index = 0; index < content.length; index++) {
      final char = content[index];
      if (char == '"') {
        if (inQuotes && index + 1 < content.length && content[index + 1] == '"') {
          field.write('"');
          index++;
        } else {
          inQuotes = !inQuotes;
        }
      } else if (char == separator && !inQuotes) {
        row.add(field.toString());
        field.clear();
      } else if ((char == '\n' || char == '\r') && !inQuotes) {
        if (char == '\r' && index + 1 < content.length && content[index + 1] == '\n') {
          index++;
        }
        row.add(field.toString());
        field.clear();
        rows.add(row);
        row = <String>[];
      } else {
        field.write(char);
      }
    }
    if (field.length > 0 || row.isNotEmpty) {
      row.add(field.toString());
      rows.add(row);
    }
    if (rows.isNotEmpty && rows.first.isNotEmpty) {
      rows.first[0] = rows.first[0].replaceFirst('\uFEFF', '');
    }
    return rows;
  }

  String _normalize(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'[áàâãä]'), 'a')
      .replaceAll(RegExp(r'[éèêë]'), 'e')
      .replaceAll(RegExp(r'[íìîï]'), 'i')
      .replaceAll(RegExp(r'[óòôõö]'), 'o')
      .replaceAll(RegExp(r'[úùûü]'), 'u')
      .replaceAll('ç', 'c');

  void _notifyListenersIfActive() {
    if (!_isDisposed) notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _httpClient.close(force: true);
    super.dispose();
  }
}

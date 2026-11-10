import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../data/open_food_facts_product.dart';

class OpenFoodFactsController extends ChangeNotifier {
  OpenFoodFactsController({HttpClient? httpClient})
      : _httpClient = httpClient ?? HttpClient();

  static const _host = 'world.openfoodfacts.org';
  static const _fields =
      'product_name,product_name_pt,product_name_en,generic_name,generic_name_pt,code,brands,quantity,categories,ingredients_text,ingredients_text_pt,allergens,nutriscore_grade,nova_group,ecoscore_grade,image_front_url,image_url';

  final HttpClient _httpClient;
  OpenFoodFactsProduct? product;
  bool isLoading = false;
  String? errorMessage;
  bool _isDisposed = false;

  void _notifyListenersIfActive() {
    if (!_isDisposed) notifyListeners();
  }

  Future<void> lookup(String rawCode) async {
    final code = rawCode.trim();
    if (code.isEmpty || !RegExp(r'^\d+$').hasMatch(code)) {
      product = null;
      errorMessage = 'Digite um código de barras válido, usando apenas números.';
      isLoading = false;
      _notifyListenersIfActive();
      return;
    }

    isLoading = true;
    product = null;
    errorMessage = null;
    _notifyListenersIfActive();

    try {
      final uri = Uri.https(_host, '/api/v3/product/$code', {
        'product_type': 'all',
        'cc': 'br',
        'lc': 'pt-br',
        'fields': _fields,
      });
      final request = await _httpClient.getUrl(uri).timeout(
            const Duration(seconds: 15),
          );
      request.headers.set(
        HttpHeaders.userAgentHeader,
        'Prateleira/1.0.0 (Flutter product lookup)',
      );
      final response = await request.close().timeout(
            const Duration(seconds: 15),
          );
      final body = await response.transform(utf8.decoder).join();

      if (response.statusCode == HttpStatus.notFound) {
        errorMessage = 'Nenhum produto encontrado para este código.';
      } else if (response.statusCode < 200 || response.statusCode >= 300) {
        errorMessage = 'A consulta falhou (HTTP ${response.statusCode}). Tente novamente.';
      } else {
        final decoded = jsonDecode(body);
        if (decoded is! Map<String, dynamic>) {
          errorMessage = 'A resposta da API veio em um formato inesperado.';
        } else if (decoded['product'] is! Map<String, dynamic> ||
            decoded['status'] == 'failure') {
          errorMessage = 'Nenhum produto encontrado para este código.';
        } else {
          product = OpenFoodFactsProduct.fromJson(
            decoded['product'] as Map<String, dynamic>,
          );
          if (product!.code.isEmpty) {
            product = OpenFoodFactsProduct.fromJson({
              ...decoded['product'] as Map<String, dynamic>,
              'code': code,
            });
          }
        }
      }
    } on TimeoutException {
      errorMessage = 'A consulta demorou demais. Verifique sua conexão e tente novamente.';
    } on SocketException {
      errorMessage = 'Não foi possível conectar à Open Food Facts. Verifique sua internet.';
    } on FormatException {
      errorMessage = 'Não foi possível interpretar a resposta da API.';
    } catch (_) {
      errorMessage = 'Ocorreu um erro ao consultar o produto. Tente novamente.';
    } finally {
      isLoading = false;
      _notifyListenersIfActive();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _httpClient.close(force: true);
    super.dispose();
  }
}

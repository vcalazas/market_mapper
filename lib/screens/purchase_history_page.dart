import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../data/purchase_database.dart';

class PurchaseHistoryPage extends StatefulWidget {
  const PurchaseHistoryPage({super.key});

  @override
  State<PurchaseHistoryPage> createState() => _PurchaseHistoryPageState();
}

class _PurchaseHistoryPageState extends State<PurchaseHistoryPage> {
  List<PurchaseSummary> _purchases = [];
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPurchases();
  }

  Future<void> _loadPurchases() async {
    try {
      final purchases = await PurchaseDatabase.instance.getAllPurchases();
      if (!mounted) return;
      setState(() {
        _purchases = purchases;
        _loading = false;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Não foi possível carregar o histórico de compras.';
      });
    }
  }

  Future<void> _importPurchases() async {
    setState(() => _busy = true);
    try {
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: const ['json'],
      );
      if (file == null || !mounted) return;
      final bytes = await file.readAsBytes();
      final count = await PurchaseDatabase.instance.importJson(utf8.decode(bytes));
      await _loadPurchases();
      if (!mounted) return;
      _showMessage(count == 0
          ? 'Nenhuma compra nova para importar; o arquivo está vazio ou já foi importado.'
          : '$count ${count == 1 ? 'compra importada' : 'compras importadas'} com sucesso.');
    } catch (error) {
      if (!mounted) return;
      final message = error is FormatException
          ? error.message
          : 'Não foi possível importar este arquivo JSON.';
      _showMessage(message.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _exportPurchases() async {
    setState(() => _busy = true);
    try {
      final json = await PurchaseDatabase.instance.exportJson();
      if (!mounted) return;
      final renderObject = context.findRenderObject();
      final origin = renderObject is RenderBox && renderObject.hasSize
          ? renderObject.localToGlobal(Offset.zero) & renderObject.size
          : null;
      await SharePlus.instance.share(
        ShareParams(
          title: 'Exportar compras',
          files: [
            XFile.fromData(
              Uint8List.fromList(utf8.encode(json)),
              mimeType: 'application/json',
            ),
          ],
          fileNameOverrides: const ['compras_prateleira.json'],
          sharePositionOrigin: origin,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      _showMessage('Não foi possível exportar as compras.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  String _currency(double value) =>
      'R\$ ${value.toStringAsFixed(2).replaceAll('.', ',')}';

  String _date(DateTime value) {
    String twoDigits(int number) => number.toString().padLeft(2, '0');
    return '${twoDigits(value.day)}/${twoDigits(value.month)}/${value.year} '
        '${twoDigits(value.hour)}:${twoDigits(value.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Histórico de compras'),
        actions: [
          IconButton(
            tooltip: 'Importar compras JSON',
            onPressed: _busy ? null : _importPurchases,
            icon: const Icon(Icons.file_upload_outlined),
          ),
          IconButton(
            tooltip: 'Exportar compras JSON',
            onPressed: _busy ? null : _exportPurchases,
            icon: const Icon(Icons.ios_share_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_loading || _busy && _purchases.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _purchases.isEmpty) {
      return _messageState(
        icon: Icons.cloud_off_outlined,
        title: 'Histórico indisponível',
        message: _error!,
        action: TextButton.icon(
          onPressed: _loadPurchases,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Tentar novamente'),
        ),
      );
    }
    if (_purchases.isEmpty) {
      return _messageState(
        icon: Icons.receipt_long_outlined,
        title: 'Nenhuma compra salva',
        message: 'As compras finalizadas aparecerão aqui. Você também pode importar um arquivo JSON.',
        action: FilledButton.icon(
          onPressed: _busy ? null : _importPurchases,
          icon: const Icon(Icons.file_upload_outlined),
          label: const Text('Importar compras'),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadPurchases,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
        itemCount: _purchases.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final purchase = _purchases[index];
          return Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => PurchaseDetailsPage(purchaseId: purchase.id),
                ),
              ),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFE7EBE5)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF5EC),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.receipt_long_outlined,
                          color: Color(0xFF1D7358)),
                    ),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Compra #${purchase.id}',
                              style: const TextStyle(
                                  color: Color(0xFF21372E),
                                  fontWeight: FontWeight.w800)),
                          const SizedBox(height: 4),
                          Text(
                            '${_date(purchase.createdAt)} · ${purchase.itemCount} ${purchase.itemCount == 1 ? 'produto' : 'produtos'}',
                            style: const TextStyle(
                                color: Color(0xFF718078), fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(_currency(purchase.total),
                        style: const TextStyle(
                            color: Color(0xFF1D7358),
                            fontWeight: FontWeight.w800)),
                    const SizedBox(width: 4),
                    const Icon(Icons.chevron_right_rounded,
                        color: Color(0xFF718078)),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _messageState({
    required IconData icon,
    required String title,
    required String message,
    required Widget action,
  }) =>
      Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 70,
                height: 70,
                decoration: const BoxDecoration(
                    color: Color(0xFFE9F2E8), shape: BoxShape.circle),
                child: Icon(icon, color: const Color(0xFF1D7358), size: 32),
              ),
              const SizedBox(height: 16),
              Text(title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Color(0xFF21372E),
                      fontWeight: FontWeight.w800,
                      fontSize: 18)),
              const SizedBox(height: 7),
              Text(message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFF718078), height: 1.4)),
              const SizedBox(height: 18),
              action,
            ],
          ),
        ),
      );
}

class PurchaseDetailsPage extends StatefulWidget {
  const PurchaseDetailsPage({super.key, required this.purchaseId});

  final int purchaseId;

  @override
  State<PurchaseDetailsPage> createState() => _PurchaseDetailsPageState();
}

class _PurchaseDetailsPageState extends State<PurchaseDetailsPage> {
  late final Future<PurchaseDetails?> _purchase;

  @override
  void initState() {
    super.initState();
    _purchase = PurchaseDatabase.instance.getPurchase(widget.purchaseId);
  }

  String _currency(double value) =>
      'R\$ ${value.toStringAsFixed(2).replaceAll('.', ',')}';

  String _date(DateTime value) {
    String twoDigits(int number) => number.toString().padLeft(2, '0');
    return '${twoDigits(value.day)}/${twoDigits(value.month)}/${value.year} '
        '${twoDigits(value.hour)}:${twoDigits(value.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Compra #${widget.purchaseId}')),
      body: FutureBuilder<PurchaseDetails?>(
        future: _purchase,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final purchase = snapshot.data;
          if (purchase == null || snapshot.hasError) {
            return const Center(child: Text('Não foi possível abrir esta compra.'));
          }
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE9F2E8),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_date(purchase.createdAt),
                          style: const TextStyle(color: Color(0xFF52665C))),
                      const SizedBox(height: 6),
                      Text(_currency(purchase.total),
                          style: const TextStyle(
                              color: Color(0xFF183C31),
                              fontSize: 25,
                              fontWeight: FontWeight.w800)),
                      Text('${purchase.items.length} ${purchase.items.length == 1 ? 'produto' : 'produtos'}',
                          style: const TextStyle(color: Color(0xFF52665C))),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                  itemCount: purchase.items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 9),
                  itemBuilder: (context, index) {
                    final entry = purchase.items[index];
                    return Container(
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(17),
                        border: Border.all(color: const Color(0xFFE7EBE5)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.inventory_2_outlined,
                              color: Color(0xFF1D7358)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(entry.product.name,
                                    style: const TextStyle(
                                        color: Color(0xFF21372E),
                                        fontWeight: FontWeight.w700)),
                                const SizedBox(height: 4),
                                Text('${entry.quantity} × ${_currency(entry.product.price)}',
                                    style: const TextStyle(
                                        color: Color(0xFF718078), fontSize: 12)),
                              ],
                            ),
                          ),
                          Text(_currency(entry.subtotal),
                              style: const TextStyle(
                                  color: Color(0xFF1D7358),
                                  fontWeight: FontWeight.w800)),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

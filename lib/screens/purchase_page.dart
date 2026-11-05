import 'package:flutter/material.dart';

import '../data/product.dart';
import '../data/product_database.dart';
import '../data/purchase_database.dart';
import 'barcode_scanner_page.dart';
import 'product_form_page.dart';

class PurchasePage extends StatefulWidget {
  const PurchasePage({super.key});

  @override
  State<PurchasePage> createState() => _PurchasePageState();
}

class _PurchasePageState extends State<PurchasePage> {
  final List<PurchaseEntry> _entries = [];
  bool _saving = false;

  double get _total => _entries.fold(0, (sum, entry) => sum + entry.subtotal);

  String _currency(double value) =>
      'R\$ ${value.toStringAsFixed(2).replaceAll('.', ',')}';

  Future<void> _scanProduct() async {
    final barcode = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const BarcodeScannerPage()),
    );
    if (barcode == null || !mounted) return;

    try {
      var product = await ProductDatabase.instance.findByBarcode(barcode);
      if (!mounted) return;
      if (product == null) {
        final draft = await Navigator.of(context).push<Product>(
          MaterialPageRoute(
            builder: (_) => ProductFormPage(initialBarcode: barcode),
          ),
        );
        if (draft == null || !mounted) return;
        await ProductDatabase.instance.save(draft);
        product = await ProductDatabase.instance.findByBarcode(barcode);
        if (product == null) throw StateError('Produto não encontrado após salvar.');
      }

      final quantity = await _askQuantity(product);
      if (quantity == null || !mounted) return;
      setState(() {
        final index = _entries.indexWhere(
          (entry) => entry.product.barcode == product!.barcode,
        );
        if (index == -1) {
          _entries.add(PurchaseEntry(product: product!, quantity: quantity));
        } else {
          final current = _entries[index];
          _entries[index] = PurchaseEntry(
            product: current.product,
            quantity: current.quantity + quantity,
          );
        }
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível adicionar o produto à compra.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<int?> _askQuantity(Product product) async {
    return showDialog<int>(
      context: context,
      builder: (_) => _QuantityDialog(productName: product.name),
    );
  }

  void _changeQuantity(int index, int delta) {
    final entry = _entries[index];
    final quantity = entry.quantity + delta;
    if (quantity < 1) {
      _entries.removeAt(index);
    }
    setState(() => _entries[index] = PurchaseEntry(
          product: entry.product,
          quantity: quantity,
        ));
  }

  Future<void> _closePurchase() async {
    if (_entries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Adicione pelo menos um produto antes de fechar a compra.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await PurchaseDatabase.instance.savePurchase(List.of(_entries));
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível salvar a compra. Tente novamente.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Modo compra'),
        actions: [
          TextButton.icon(
            onPressed: _saving ? null : _closePurchase,
            icon: _saving
                ? const SizedBox(
                    width: 17,
                    height: 17,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check_rounded),
            label: const Text('Fechar'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: _entries.isEmpty
            ? _emptyState()
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                itemCount: _entries.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) => _purchaseItem(index),
              ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Color(0xFFE7EBE5))),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Total da compra',
                        style: TextStyle(color: Color(0xFF718078), fontSize: 13)),
                    const SizedBox(height: 3),
                    Text(_currency(_total),
                        style: const TextStyle(
                            color: Color(0xFF183C31),
                            fontSize: 21,
                            fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: _saving ? null : _scanProduct,
                icon: const Icon(Icons.qr_code_scanner_rounded),
                label: const Text('Escanear item'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _emptyState() => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(
                    color: Color(0xFFE9F2E8), shape: BoxShape.circle),
                child: const Icon(Icons.shopping_cart_outlined,
                    color: Color(0xFF1D7358), size: 34),
              ),
              const SizedBox(height: 16),
              const Text('Sua compra começa aqui',
                  style: TextStyle(
                      color: Color(0xFF21372E),
                      fontWeight: FontWeight.w800,
                      fontSize: 18)),
              const SizedBox(height: 7),
              const Text(
                'Escaneie os produtos. Se algum ainda não estiver no catálogo, você poderá cadastrá-lo.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF718078), height: 1.4),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: _scanProduct,
                icon: const Icon(Icons.qr_code_scanner_rounded),
                label: const Text('Escanear primeiro item'),
              ),
            ],
          ),
        ),
      );

  Widget _purchaseItem(int index) {
    final entry = _entries[index];
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 13, 12, 13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE7EBE5)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
                color: const Color(0xFFEFF5EC),
                borderRadius: BorderRadius.circular(14)),
            child: const Icon(Icons.inventory_2_outlined,
                color: Color(0xFF1D7358)),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.product.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Color(0xFF21372E), fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text('${_currency(entry.product.price)} cada',
                    style: const TextStyle(
                        color: Color(0xFF718078), fontSize: 12)),
                const SizedBox(height: 5),
                Text(_currency(entry.subtotal),
                    style: const TextStyle(
                        color: Color(0xFF1D7358), fontWeight: FontWeight.w800)),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Diminuir quantidade',
            onPressed: entry.quantity > 1 ? () => _changeQuantity(index, -1) : null,
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.remove_circle_outline_rounded),
          ),
          Text('${entry.quantity}',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
          IconButton(
            tooltip: 'Aumentar quantidade',
            onPressed: () => _changeQuantity(index, 1),
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.add_circle_outline_rounded),
          ),
        ],
      ),
    );
  }
}

class _QuantityDialog extends StatefulWidget {
  const _QuantityDialog({required this.productName});

  final String productName;

  @override
  State<_QuantityDialog> createState() => _QuantityDialogState();
}

class _QuantityDialogState extends State<_QuantityDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: '1');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final quantity = int.tryParse(_controller.text.trim());
    if (quantity == null || quantity < 1) return;
    Navigator.of(context).pop(quantity);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Quantidade'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.productName,
                style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 14),
            TextField(
              controller: _controller,
              autofocus: true,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Unidades',
                prefixIcon: Icon(Icons.inventory_2_outlined),
              ),
              onSubmitted: (_) => _submit(),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: _submit,
            child: const Text('Adicionar'),
          ),
        ],
      );
}

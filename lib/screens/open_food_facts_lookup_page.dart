import 'package:flutter/material.dart';

import 'barcode_scanner_page.dart';
import '../controllers/open_food_facts_controller.dart';
import '../data/open_food_facts_product.dart';

class OpenFoodFactsLookupPage extends StatefulWidget {
  const OpenFoodFactsLookupPage({super.key});

  static const routeName = '/consulta-produto-api';

  @override
  State<OpenFoodFactsLookupPage> createState() =>
      _OpenFoodFactsLookupPageState();
}

class _OpenFoodFactsLookupPageState extends State<OpenFoodFactsLookupPage> {
  final _codeController = TextEditingController();
  final _controller = OpenFoodFactsController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_refresh);
  }

  @override
  void dispose() {
    _controller.removeListener(_refresh);
    _controller.dispose();
    _codeController.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  void _lookup() {
    FocusScope.of(context).unfocus();
    _controller.lookup(_codeController.text);
  }

  Future<void> _scanBarcode() async {
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const BarcodeScannerPage()),
    );
    if (code == null || !mounted) return;
    _codeController.text = code;
    await _controller.lookup(code);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Consulta experimental'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFFE9F2E8),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.travel_explore_rounded,
                      color: Color(0xFF1D7358), size: 26),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Buscar na Open Food Facts',
                            style: TextStyle(
                                color: Color(0xFF20362E),
                                fontWeight: FontWeight.w800,
                                fontSize: 16)),
                        SizedBox(height: 5),
                        Text(
                          'Informe o código de barras para consultar os dados públicos do produto.',
                          style: TextStyle(
                              color: Color(0xFF5F7067), height: 1.4),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _codeController,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _lookup(),
              decoration: InputDecoration(
                labelText: 'Código de barras',
                hintText: 'Ex.: 3017620422003',
                prefixIcon: const Icon(Icons.qr_code_2_rounded),
                suffixIcon: IconButton(
                  tooltip: 'Ler código com a câmera',
                  onPressed: _controller.isLoading ? null : _scanBarcode,
                  icon: const Icon(Icons.qr_code_scanner_rounded),
                ),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _controller.isLoading ? null : _lookup,
              icon: _controller.isLoading
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.search_rounded),
              label: Text(_controller.isLoading ? 'Consultando…' : 'Consultar produto'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
            ),
            const SizedBox(height: 22),
            if (_controller.errorMessage case final message?)
              _LookupMessage(message: message)
            else if (_controller.product case final product?)
              _ProductResult(product: product)
            else if (!_controller.isLoading)
              const _LookupHint(),
          ],
        ),
      ),
    );
  }
}

class _LookupHint extends StatelessWidget {
  const _LookupHint();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 28),
      child: Column(
        children: [
          Icon(Icons.inventory_2_outlined, size: 38, color: Color(0xFF91A097)),
          SizedBox(height: 10),
          Text('O resultado da consulta aparecerá aqui.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF718078))),
        ],
      ),
    );
  }
}

class _LookupMessage extends StatelessWidget {
  const _LookupMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF2E8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF4D9C3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded, color: Color(0xFF9B5422)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message,
                style: const TextStyle(color: Color(0xFF75441F), height: 1.4)),
          ),
        ],
      ),
    );
  }
}

class _ProductResult extends StatelessWidget {
  const _ProductResult({required this.product});

  final OpenFoodFactsProduct product;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Resultado',
            style: TextStyle(
                color: Color(0xFF20362E),
                fontWeight: FontWeight.w800,
                fontSize: 18)),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE3E8E2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (product.imageUrl != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.network(
                    product.imageUrl!,
                    height: 190,
                    width: double.infinity,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              Text(product.name,
                  style: const TextStyle(
                      color: Color(0xFF20362E),
                      fontSize: 20,
                      fontWeight: FontWeight.w800)),
              if (product.brands != null) ...[
                const SizedBox(height: 4),
                Text(product.brands!,
                    style: const TextStyle(color: Color(0xFF718078))),
              ],
              const SizedBox(height: 14),
              _ResultLine(label: 'Código', value: product.code),
              if (product.quantity != null)
                _ResultLine(label: 'Quantidade', value: product.quantity!),
              if (product.categories != null)
                _ResultLine(label: 'Categorias', value: product.categories!),
              if (product.nutriscore != null)
                _ResultLine(
                    label: 'Nutri-Score', value: product.nutriscore!.toUpperCase()),
              if (product.novaGroup != null)
                _ResultLine(label: 'Grupo NOVA', value: '${product.novaGroup}'),
              if (product.ecoscore != null)
                _ResultLine(
                    label: 'Eco-Score', value: product.ecoscore!.toUpperCase()),
              if (product.allergens != null)
                _ResultLine(label: 'Alérgenos', value: product.allergens!),
              if (product.ingredients != null) ...[
                const SizedBox(height: 12),
                const Text('Ingredientes',
                    style: TextStyle(
                        color: Color(0xFF20362E), fontWeight: FontWeight.w700)),
                const SizedBox(height: 5),
                Text(product.ingredients!,
                    style: const TextStyle(
                        color: Color(0xFF5F7067), height: 1.4)),
              ],
            ],
          ),
        ),
        const SizedBox(height: 8),
        const Text('Dados fornecidos pela Open Food Facts.',
            style: TextStyle(color: Color(0xFF718078), fontSize: 12)),
      ],
    );
  }
}

class _ResultLine extends StatelessWidget {
  const _ResultLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 105,
            child: Text(label,
                style: const TextStyle(
                    color: Color(0xFF718078), fontWeight: FontWeight.w600)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    color: Color(0xFF20362E), fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}

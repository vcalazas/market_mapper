import 'package:flutter/material.dart';

import '../data/product.dart';

class ProductFormPage extends StatefulWidget {
  const ProductFormPage({super.key, this.product, this.initialBarcode = ''});

  final Product? product;
  final String initialBarcode;

  @override
  State<ProductFormPage> createState() => _ProductFormPageState();
}

class _ProductFormPageState extends State<ProductFormPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _barcodeController;
  late final TextEditingController _nameController;
  late final TextEditingController _priceController;

  @override
  void initState() {
    super.initState();
    _barcodeController = TextEditingController(
        text: widget.product?.barcode ?? widget.initialBarcode);
    _nameController = TextEditingController(text: widget.product?.name ?? '');
    _priceController = TextEditingController(
      text: widget.product == null
          ? ''
          : widget.product!.price.toStringAsFixed(2).replaceAll('.', ','),
    );
  }

  @override
  void dispose() {
    _barcodeController.dispose();
    _nameController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final normalized = _normalizePrice(_priceController.text);
    Navigator.of(context).pop(Product(
      id: widget.product?.id,
      barcode: _barcodeController.text.trim(),
      name: _nameController.text.trim(),
      price: double.parse(normalized),
    ));
  }

  String _normalizePrice(String value) {
    final trimmed = value.trim();
    return trimmed.contains(',')
        ? trimmed.replaceAll('.', '').replaceAll(',', '.')
        : trimmed;
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.product != null;
    return Scaffold(
      appBar: AppBar(title: Text(editing ? 'Editar produto' : 'Novo produto')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFFE9F2E8),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.inventory_2_outlined,
                        size: 32, color: Color(0xFF1D7358)),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        editing
                            ? 'Atualize as informações deste item.'
                            : 'Preencha os dados para guardar o produto no seu catálogo.',
                        style: const TextStyle(
                            color: Color(0xFF29443A), height: 1.35),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const _FieldLabel('Código de barras'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _barcodeController,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  hintText: 'Digite ou leia o código',
                  prefixIcon: Icon(Icons.qr_code_2_rounded),
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Informe o código de barras'
                    : null,
              ),
              const SizedBox(height: 18),
              const _FieldLabel('Nome do produto'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameController,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  hintText: 'Ex.: Café em grãos',
                  prefixIcon: Icon(Icons.sell_outlined),
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Informe o nome do produto'
                    : null,
              ),
              const SizedBox(height: 18),
              const _FieldLabel('Preço'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _priceController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  hintText: '0,00',
                  prefixText: 'R\$ ',
                  prefixIcon: Icon(Icons.attach_money_rounded),
                ),
                validator: (value) {
                  final parsed = double.tryParse(_normalizePrice(value ?? ''));
                  if (parsed == null || parsed < 0) return 'Informe um preço válido';
                  return null;
                },
              ),
              const SizedBox(height: 28),
              FilledButton.icon(
                onPressed: _submit,
                icon: Icon(editing ? Icons.check_rounded : Icons.save_rounded),
                label: Text(editing ? 'Salvar alterações' : 'Salvar produto'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  textStyle: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
            color: Color(0xFF263A32), fontWeight: FontWeight.w700, fontSize: 14),
      );
}

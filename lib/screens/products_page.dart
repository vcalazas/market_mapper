import 'package:flutter/material.dart';

import '../data/product.dart';
import '../data/product_database.dart';
import 'barcode_scanner_page.dart';
import 'product_form_page.dart';

class ProductsPage extends StatefulWidget {
  const ProductsPage({super.key});

  @override
  State<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends State<ProductsPage> {
  final _searchController = TextEditingController();
  List<Product> _products = [];
  bool _loading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    try {
      final products = await ProductDatabase.instance
          .getAll(query: _searchController.text.trim());
      if (!mounted) return;
      setState(() {
        _products = products;
        _loading = false;
        _loadError = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = 'Não foi possível carregar seus produtos.';
      });
    }
  }

  Future<void> _scanBarcode() async {
    final barcode = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const BarcodeScannerPage()),
    );
    if (barcode == null || !mounted) return;
    final existing = await ProductDatabase.instance.findByBarcode(barcode);
    if (!mounted) return;
    await _openForm(product: existing, barcode: barcode);
  }

  Future<void> _openForm({Product? product, String barcode = ''}) async {
    final saved = await Navigator.of(context).push<Product>(
      MaterialPageRoute(
        builder: (_) => ProductFormPage(product: product, initialBarcode: barcode),
      ),
    );
    if (saved == null || !mounted) return;
    try {
      await ProductDatabase.instance.save(saved);
      await _loadProducts();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(product == null
              ? 'Produto salvo com sucesso.'
              : 'Produto atualizado com sucesso.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Este código já está cadastrado. Confira o produto existente.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _deleteProduct(Product product) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir produto?'),
        content: Text('“${product.name}” será removido do catálogo.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (shouldDelete != true || product.id == null) return;
    await ProductDatabase.instance.delete(product.id!);
    await _loadProducts();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Produto excluído.'), behavior: SnackBarBehavior.floating),
    );
  }

  String _currency(double value) =>
      'R\$ ${value.toStringAsFixed(2).replaceAll('.', ',')}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: const Row(
          children: [
            Icon(Icons.widgets_rounded, color: Color(0xFF1D7358)),
            SizedBox(width: 9),
            Text('Prateleira',
                style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.4)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Ler código de barras',
            onPressed: _scanBarcode,
            icon: const Icon(Icons.document_scanner_outlined),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: _heroCard(),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
              child: TextField(
                controller: _searchController,
                onChanged: (_) => _loadProducts(),
                decoration: InputDecoration(
                  hintText: 'Buscar produto ou código',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _searchController.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Limpar busca',
                          onPressed: () {
                            _searchController.clear();
                            _loadProducts();
                            setState(() {});
                          },
                          icon: const Icon(Icons.close_rounded),
                        ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 0, 22, 10),
              child: Row(
                children: [
                  const Expanded(
                    child: Text('Seus produtos',
                        style: TextStyle(
                            color: Color(0xFF20362E),
                            fontSize: 18,
                            fontWeight: FontWeight.w800)),
                  ),
                  Text('${_products.length} itens',
                      style: const TextStyle(
                          color: Color(0xFF718078), fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            Expanded(child: _buildProductList()),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _scanBarcode,
        icon: const Icon(Icons.qr_code_scanner_rounded),
        label: const Text('Ler produto'),
      ),
    );
  }

  Widget _heroCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF183C31),
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [Color(0xFF1B4739), Color(0xFF17372D)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Seu catálogo,\nsempre à mão.',
                    style: TextStyle(
                        color: Colors.white,
                        height: 1.12,
                        fontSize: 23,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5)),
                const SizedBox(height: 8),
                Text(
                  _products.isEmpty
                      ? 'Leia um código e cadastre seu primeiro produto.'
                      : 'Produtos organizados em um só lugar.',
                  style: const TextStyle(color: Color(0xFFC8D9CE), fontSize: 13),
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: _scanBarcode,
                  icon: const Icon(Icons.center_focus_strong_rounded, size: 18),
                  label: const Text('Escanear agora'),
                  style: FilledButton.styleFrom(
                    foregroundColor: const Color(0xFF15372C),
                    backgroundColor: const Color(0xFFB9EF78),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(22),
            ),
            child: const Icon(Icons.qr_code_2_rounded,
                size: 42, color: Color(0xFFB9EF78)),
          ),
        ],
      ),
    );
  }

  Widget _buildProductList() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_loadError != null) {
      return _emptyState(
        icon: Icons.cloud_off_outlined,
        title: 'Não foi possível abrir o catálogo',
        detail: _loadError!,
        action: TextButton.icon(
            onPressed: _loadProducts,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Tentar novamente')),
      );
    }
    if (_products.isEmpty) {
      final searching = _searchController.text.isNotEmpty;
      return _emptyState(
        icon: searching ? Icons.search_off_rounded : Icons.inventory_2_outlined,
        title: searching ? 'Nenhum resultado' : 'Seu catálogo está vazio',
        detail: searching
            ? 'Tente buscar por outro nome ou código.'
            : 'Seus produtos aparecerão aqui depois da primeira leitura.',
        action: searching
            ? TextButton(
                onPressed: () {
                  _searchController.clear();
                  _loadProducts();
                  setState(() {});
                },
                child: const Text('Limpar busca'))
            : OutlinedButton.icon(
                onPressed: () => _openForm(),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Cadastrar manualmente'),
              ),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadProducts,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 2, 20, 100),
        itemCount: _products.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final product = _products[index];
          return _ProductCard(
            product: product,
            price: _currency(product.price),
            onTap: () => _openForm(product: product),
            onEdit: () => _openForm(product: product),
            onDelete: () => _deleteProduct(product),
          );
        },
      ),
    );
  }

  Widget _emptyState({
    required IconData icon,
    required String title,
    required String detail,
    required Widget action,
  }) {
    return Center(
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(32, 16, 32, 100),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 68,
              height: 68,
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
                    fontSize: 17)),
            const SizedBox(height: 7),
            Text(detail,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF718078), height: 1.4)),
            const SizedBox(height: 16),
            action,
          ],
        ),
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.product,
    required this.price,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  final Product product;
  final String price;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 13, 8, 13),
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
                child: const Icon(Icons.inventory_2_outlined,
                    color: Color(0xFF1D7358)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(product.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Color(0xFF21372E),
                            fontSize: 15,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 5),
                    Text(product.barcode,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Color(0xFF77827B), fontSize: 12)),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(price,
                      style: const TextStyle(
                          color: Color(0xFF1D7358),
                          fontWeight: FontWeight.w800,
                          fontSize: 14)),
                  SizedBox(
                    height: 27,
                    child: PopupMenuButton<String>(
                      padding: EdgeInsets.zero,
                      iconSize: 18,
                      tooltip: 'Ações do produto',
                      onSelected: (value) => value == 'edit' ? onEdit() : onDelete(),
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'edit', child: Text('Editar')),
                        PopupMenuItem(value: 'delete', child: Text('Excluir')),
                      ],
                      icon: const Icon(Icons.more_horiz_rounded,
                          color: Color(0xFF718078)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

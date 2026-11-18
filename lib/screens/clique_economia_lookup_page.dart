import 'package:flutter/material.dart';

import '../controllers/clique_economia_controller.dart';
import '../data/clique_economia_quote.dart';

class CliqueEconomiaLookupPage extends StatefulWidget {
  const CliqueEconomiaLookupPage({super.key});

  static const routeName = '/clique-economia-experimental';

  @override
  State<CliqueEconomiaLookupPage> createState() =>
      _CliqueEconomiaLookupPageState();
}

class _CliqueEconomiaLookupPageState extends State<CliqueEconomiaLookupPage> {
  final _searchController = TextEditingController();
  final _controller = CliqueEconomiaController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_refresh);
    _controller.loadLatest();
  }

  @override
  void dispose() {
    _controller.removeListener(_refresh);
    _controller.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  String _currency(double value) =>
      'R\$ ${value.toStringAsFixed(2).replaceAll('.', ',')}';

  String? _publishedDate(String? filename) {
    if (filename == null) return null;
    final date = DateTime.tryParse(filename.substring(0, 10));
    if (date == null) return null;
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final publishedDate = _publishedDate(_controller.sourceFile);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Preços em Curitiba'),
        actions: [
          IconButton(
            tooltip: 'Atualizar base',
            onPressed: _controller.isLoading ? null : _controller.loadLatest,
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(17),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE9F2E8),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.storefront_rounded,
                            color: Color(0xFF1D7358), size: 26),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Compare preços por mercado',
                                  style: TextStyle(
                                      color: Color(0xFF20362E),
                                      fontWeight: FontWeight.w800,
                                      fontSize: 16)),
                              SizedBox(height: 5),
                              Text(
                                'Cotações públicas do programa Clique Economia, em Curitiba.',
                                style: TextStyle(
                                    color: Color(0xFF5F7067), height: 1.4),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _searchController,
                    textInputAction: TextInputAction.search,
                    onChanged: _controller.setQuery,
                    decoration: InputDecoration(
                      labelText: 'Buscar produto',
                      hintText: 'Ex.: arroz, leite ou café',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _searchController.text.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Limpar busca',
                              onPressed: () {
                                _searchController.clear();
                                _controller.setQuery('');
                              },
                              icon: const Icon(Icons.close_rounded),
                            ),
                    ),
                  ),
                  if (publishedDate != null) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(Icons.update_rounded,
                            size: 16, color: Color(0xFF718078)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Base consultada em $publishedDate · ${_controller.productCount} produtos',
                            style: const TextStyle(
                                color: Color(0xFF718078), fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            Expanded(child: _buildResults()),
          ],
        ),
      ),
    );
  }

  Widget _buildResults() {
    if (_controller.isLoading && _controller.sourceFile == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_controller.errorMessage != null && _controller.sourceFile == null) {
      return _messageState(
        icon: Icons.cloud_off_outlined,
        title: 'Não foi possível abrir as cotações',
        detail: _controller.errorMessage!,
        action: TextButton.icon(
          onPressed: _controller.loadLatest,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Tentar novamente'),
        ),
      );
    }
    if (_controller.visibleProducts.isEmpty) {
      return _messageState(
        icon: Icons.search_off_rounded,
        title: 'Nenhum produto encontrado',
        detail: 'Tente buscar por outro nome ou código.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 0, 22, 9),
          child: Text(
            _controller.query.trim().isEmpty
                ? 'Produtos com menor preço'
                : '${_controller.visibleProducts.length} resultados',
            style: const TextStyle(
                color: Color(0xFF20362E),
                fontSize: 16,
                fontWeight: FontWeight.w800),
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
            itemCount: _controller.visibleProducts.length,
            separatorBuilder: (_, _) => const SizedBox(height: 9),
            itemBuilder: (context, index) => _ProductPriceCard(
              product: _controller.visibleProducts[index],
              currency: _currency,
            ),
          ),
        ),
      ],
    );
  }

  Widget _messageState({
    required IconData icon,
    required String title,
    required String detail,
    Widget? action,
  }) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(32, 16, 32, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: const Color(0xFF1D7358), size: 40),
            const SizedBox(height: 14),
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
            if (action != null) ...[const SizedBox(height: 14), action],
          ],
        ),
      ),
    );
  }
}

class _ProductPriceCard extends StatelessWidget {
  const _ProductPriceCard({required this.product, required this.currency});

  final CliqueEconomiaProduct product;
  final String Function(double) currency;

  @override
  Widget build(BuildContext context) {
    final quotes = [...product.quotes]
      ..sort((a, b) => a.displayedPrice.compareTo(b.displayedPrice));
    return Card(
      margin: EdgeInsets.zero,
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(17),
        side: const BorderSide(color: Color(0xFFE3E8E2)),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.fromLTRB(15, 4, 12, 4),
        childrenPadding: const EdgeInsets.fromLTRB(15, 0, 15, 12),
        title: Text(product.description,
            style: const TextStyle(
                color: Color(0xFF20362E), fontWeight: FontWeight.w700)),
        subtitle: Text('${quotes.length} mercados · menor preço',
            style: const TextStyle(color: Color(0xFF718078), fontSize: 12)),
        trailing: Text(
          currency(product.lowestPrice),
          style: const TextStyle(
              color: Color(0xFF1D7358),
              fontSize: 15,
              fontWeight: FontWeight.w800),
        ),
        children: [
          const Divider(height: 1),
          const SizedBox(height: 5),
          for (final quote in quotes) _QuoteLine(quote: quote, currency: currency),
        ],
      ),
    );
  }
}

class _QuoteLine extends StatelessWidget {
  const _QuoteLine({required this.quote, required this.currency});

  final CliqueEconomiaQuote quote;
  final String Function(double) currency;

  @override
  Widget build(BuildContext context) {
    final hasDiscount = quote.displayedPrice < quote.regularPrice;
    return Padding(
      padding: const EdgeInsets.only(top: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.store_outlined,
              size: 17, color: Color(0xFF718078)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(quote.store,
                    style: const TextStyle(
                        color: Color(0xFF20362E), fontWeight: FontWeight.w600)),
                Text(quote.address,
                    style: const TextStyle(
                        color: Color(0xFF718078), fontSize: 11, height: 1.3)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(currency(quote.displayedPrice),
                  style: const TextStyle(
                      color: Color(0xFF1D7358), fontWeight: FontWeight.w800)),
              if (hasDiscount)
                Text(currency(quote.regularPrice),
                    style: const TextStyle(
                        color: Color(0xFF718078),
                        fontSize: 11,
                        decoration: TextDecoration.lineThrough)),
            ],
          ),
        ],
      ),
    );
  }
}

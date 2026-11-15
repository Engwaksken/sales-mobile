import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api_client.dart';
import '../core/config.dart';

class CustomerProductsScreen extends StatefulWidget {
  const CustomerProductsScreen({super.key});

  @override
  State<CustomerProductsScreen> createState() => _CustomerProductsScreenState();
}

class _CustomerProductsScreenState extends State<CustomerProductsScreen> {
  bool loading = true;
  List<dynamic> rows = [];
  String query = '';

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final response = await context.read<ApiClient>().get('/customer/products');

    if (!mounted) return;

    setState(() {
      rows = List<dynamic>.from(response.data['data'] ?? []);
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());

    final filtered = rows.where((raw) {
      final row = Map<String, dynamic>.from(raw as Map);
      final needle = query.toLowerCase();

      return '${row['name'] ?? ''}'.toLowerCase().contains(needle) ||
          '${row['sku'] ?? ''}'.toLowerCase().contains(needle);
    }).toList();

    return RefreshIndicator(
      onRefresh: load,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          TextField(
            onChanged: (value) => setState(() => query = value),
            decoration: InputDecoration(
              hintText: 'Search products',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 14),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: filtered.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: .72,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemBuilder: (_, index) {
              final row = Map<String, dynamic>.from(filtered[index] as Map);
              final rawImageUrl = '${row['image_url'] ?? row['image'] ?? ''}'
                  .trim();
              final imageUrl = rawImageUrl.isEmpty
                  ? ''
                  : (Uri.tryParse(rawImageUrl)?.hasScheme == true
                        ? rawImageUrl
                        : Uri.parse(AppConfig.apiOrigin)
                              .resolve(
                                rawImageUrl.startsWith('/')
                                    ? rawImageUrl
                                    : '/$rawImageUrl',
                              )
                              .toString());

              return Card(
                elevation: 0,
                clipBehavior: Clip.antiAlias,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Container(
                        width: double.infinity,
                        color: const Color(0xFFF8FAFC),
                        child: imageUrl.isEmpty
                            ? const Icon(
                                Icons.image_outlined,
                                size: 52,
                                color: Color(0xFFCBD5E1),
                              )
                            : Image.network(
                                imageUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => const Icon(
                                  Icons.broken_image_outlined,
                                  size: 48,
                                ),
                              ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${row['name'] ?? 'Product'}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            'UGX ${row['selling_price'] ?? 0}',
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${row['available'] ?? 0} available',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

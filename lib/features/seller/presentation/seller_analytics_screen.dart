import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../../core/models/order_model.dart';
import '../../auth/data/auth_repository.dart';
import '../../buyer/data/order_repository.dart';
import 'dart:math';

// Provider to fetch seller orders for analytics
final analyticsOrdersProvider = StreamProvider.family<List<OrderModel>, String>((ref, sellerId) {
  return ref.watch(orderRepositoryProvider).getSellerOrders(sellerId);
});

class SellerAnalyticsScreen extends ConsumerStatefulWidget {
  const SellerAnalyticsScreen({super.key});

  @override
  ConsumerState<SellerAnalyticsScreen> createState() => _SellerAnalyticsScreenState();
}

class _SellerAnalyticsScreenState extends ConsumerState<SellerAnalyticsScreen> {
  String _timeRange = 'Monthly'; // 'Daily', 'Weekly', 'Monthly'

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authRepositoryProvider).currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: Text('Unauthorized')));
    }

    final ordersAsync = ref.watch(analyticsOrdersProvider(user.id));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sales & Analytics'),
        centerTitle: true,
      ),
      body: ordersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Error: $error')),
        data: (orders) {
          if (orders.isEmpty) {
            return const Center(child: Text('No sales data available yet.'));
          }
          return _buildDashboard(orders, user.id);
        },
      ),
    );
  }

  Widget _buildDashboard(List<OrderModel> orders, String sellerId) {
    // Filter out canceled/returned orders for accurate revenue
    final validOrders = orders.where((o) =>
        o.status != OrderModel.statusCancelled &&
        o.status != OrderModel.statusReturned).toList();

    // 1. Calculate main KPIs
    double totalRevenue = 0;
    int totalItemsSold = 0;
    
    // Only count revenue for items sold by THIS seller
    for (var order in validOrders) {
      for (var item in order.items) {
        if (item.book.sellerId == sellerId) {
          totalRevenue += item.price * item.quantity;
          totalItemsSold += item.quantity;
        }
      }
    }

    // 2. Compute Top Selling Books & Categories
    final Map<String, int> bookSales = {};
    final Map<String, double> categoryRevenue = {};
    final Set<String> uniqueBuyers = {}; // For customer behavior

    for (var order in validOrders) {
      uniqueBuyers.add(order.userId);
      for (var item in order.items) {
        if (item.book.sellerId == sellerId) {
          // Book count
          bookSales[item.title] = (bookSales[item.title] ?? 0) + item.quantity;
          // Category revenue
          categoryRevenue[item.book.genre] = (categoryRevenue[item.book.genre] ?? 0) + (item.price * item.quantity);
        }
      }
    }

    // 3. Prepare data for charts
    final topBooks = bookSales.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final displayTopBooks = topBooks.take(5).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTimeRangeSelector(),
          const SizedBox(height: 16),
          
          // KPI Cards
          Row(
            children: [
              Expanded(child: _buildKPICard('Total Revenue', '\$${totalRevenue.toStringAsFixed(2)}', Icons.attach_money, Colors.green)),
              const SizedBox(width: 12),
              Expanded(child: _buildKPICard('Items Sold', '$totalItemsSold', Icons.shopping_basket, Colors.blue)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildKPICard('Total Orders', '${validOrders.length}', Icons.receipt_long, Colors.orange)),
              const SizedBox(width: 12),
              Expanded(child: _buildKPICard('Unique Buyers', '${uniqueBuyers.length}', Icons.people, Colors.purple)),
            ],
          ),
          
          const SizedBox(height: 24),
          const Text('Revenue Trends', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _buildRevenueChart(validOrders, sellerId),

          const SizedBox(height: 32),
          const Text('Top Performing Books', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _buildTopBooksList(displayTopBooks),

          const SizedBox(height: 32),
          const Text('Sales by Category', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _buildCategoryPieChart(categoryRevenue),
          
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildTimeRangeSelector() {
    return Center(
      child: SegmentedButton<String>(
        segments: const [
          ButtonSegment(value: 'Daily', label: Text('Daily')),
          ButtonSegment(value: 'Weekly', label: Text('Weekly')),
          ButtonSegment(value: 'Monthly', label: Text('Monthly')),
        ],
        selected: {_timeRange},
        onSelectionChanged: (Set<String> newSelection) {
          setState(() {
            _timeRange = newSelection.first;
          });
        },
      ),
    );
  }

  Widget _buildKPICard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(title, style: TextStyle(fontSize: 12, color: Colors.grey[600]), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildRevenueChart(List<OrderModel> orders, String sellerId) {
    // Group revenue by time period
    final Map<String, double> revenueData = {};
    DateTime now = DateTime.now();
    
    for (var order in orders) {
      double orderSellerRevenue = 0;
      for (var item in order.items) {
        if (item.book.sellerId == sellerId) {
          orderSellerRevenue += item.price * item.quantity;
        }
      }
      
      if (orderSellerRevenue == 0) continue;

      String key = '';
      if (_timeRange == 'Daily') {
        // Last 7 days
        if (now.difference(order.timestamp).inDays <= 7) {
          key = DateFormat('E').format(order.timestamp); // Mon, Tue
        }
      } else if (_timeRange == 'Weekly') {
        // Last 4 weeks
        if (now.difference(order.timestamp).inDays <= 28) {
          key = 'Wk ${((now.difference(order.timestamp).inDays) / 7).ceil()}';
        }
      } else {
        // Monthly - Last 6 months
        if (now.difference(order.timestamp).inDays <= 180) {
          key = DateFormat('MMM').format(order.timestamp); // Jan, Feb
        }
      }
      
      if (key.isNotEmpty) {
        revenueData[key] = (revenueData[key] ?? 0) + orderSellerRevenue;
      }
    }

    if (revenueData.isEmpty) {
      return const SizedBox(
        height: 200, 
        child: Center(child: Text('Not enough data for this time range.'))
      );
    }

    final sortedKeys = revenueData.keys.toList().reversed.toList();
    List<FlSpot> spots = [];
    double maxX = sortedKeys.length.toDouble() - 1;
    double maxY = 0;

    for (int i = 0; i < sortedKeys.length; i++) {
      double val = revenueData[sortedKeys[i]]!;
      spots.add(FlSpot(i.toDouble(), val));
      if (val > maxY) maxY = val;
    }

    return Container(
      height: 250,
      padding: const EdgeInsets.only(right: 16, top: 16, bottom: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
      ),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(show: true, drawVerticalLine: false),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (value, meta) {
                  return Text('\$${value.toInt()}');
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  int index = value.toInt();
                  if (index >= 0 && index < sortedKeys.length) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(sortedKeys[index], style: const TextStyle(fontSize: 10)),
                    );
                  }
                  return const Text('');
                },
              ),
            ),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          minX: 0,
          maxX: maxX,
          minY: 0,
          maxY: maxY * 1.2,
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: Theme.of(context).primaryColor,
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: FlDotData(show: true),
              belowBarData: BarAreaData(
                show: true,
                color: Theme.of(context).primaryColor.withValues(alpha: 0.2),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBooksList(List<MapEntry<String, int>> topBooks) {
    if (topBooks.isEmpty) {
      return const Text('No books sold yet.');
    }
    
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: topBooks.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final entry = topBooks[index];
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).primaryColor.withValues(alpha: 0.1),
              child: Text('#${index + 1}', style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold)),
            ),
            title: Text(entry.key, style: const TextStyle(fontWeight: FontWeight.w600)),
            trailing: Text('${entry.value} sold', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          );
        },
      ),
    );
  }

  Widget _buildCategoryPieChart(Map<String, double> categoryRevenue) {
    if (categoryRevenue.isEmpty) {
      return const Text('No category data available.');
    }

    final colors = [
      Colors.blue, Colors.red, Colors.green, Colors.orange, 
      Colors.purple, Colors.teal, Colors.pink
    ];
    
    int colorIndex = 0;
    List<PieChartSectionData> sections = [];
    
    categoryRevenue.forEach((category, revenue) {
      sections.add(
        PieChartSectionData(
          color: colors[colorIndex % colors.length],
          value: revenue,
          title: '${category}\n\$${revenue.toInt()}',
          radius: 60,
          titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
        ),
      );
      colorIndex++;
    });

    return Container(
      height: 250,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
      ),
      child: PieChart(
        PieChartData(
          sectionsSpace: 2,
          centerSpaceRadius: 40,
          sections: sections,
        ),
      ),
    );
  }
}

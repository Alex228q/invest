import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() {
  runApp(const InvestmentApp());
}

class InvestmentApp extends StatelessWidget {
  const InvestmentApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Инвестиционный калькулятор',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const InvestmentScreen(),
    );
  }
}

class InvestmentScreen extends StatefulWidget {
  const InvestmentScreen({super.key});

  @override
  _InvestmentScreenState createState() => _InvestmentScreenState();
}

class _InvestmentScreenState extends State<InvestmentScreen> {
  final TextEditingController _currentStocksController =
      TextEditingController();
  final TextEditingController _currentBondsController = TextEditingController();
  final TextEditingController _currentGoldController = TextEditingController();
  final TextEditingController _currentYanController = TextEditingController();
  final TextEditingController _newFundsController = TextEditingController();
  final TextEditingController _totalAmountController = TextEditingController();

  bool _isLoading = false;
  String? _error;
  double _totalStocksCost = 0;

  final Map<String, Map<String, dynamic>> _stockInfo = {
    'SBER': {'name': 'Сбербанк', 'lotSize': 10},
    'GMKN': {'name': 'Норникель', 'lotSize': 10},
    'PHOR': {'name': 'Фосагро', 'lotSize': 1},
    'SNGSP': {'name': 'Сургутнефтегаз-п', 'lotSize': 10},
    'NVTK': {'name': 'Новатэк', 'lotSize': 1},
    'PLZL': {'name': 'Полюс', 'lotSize': 1},
  };

  Map<String, double?> stockPrices = {};
  Map<String, int> stockLots = {};
  Map<String, double> actualAllocation = {};

  final Map<String, double> stocksDistribution = {
    'SBER': 0.15,
    'SNGSP': 0.15,
    'NVTK': 0.15,
    'GMKN': 0.20,
    'PHOR': 0.20,
    'PLZL': 0.15,
  };

  Map<String, double> allocationResults = {
    'Акции (45%)': 0,
    'Облигации (25%)': 0,
    'Золото (20%)': 0,
    'Юани (10%)': 0,
  };

  Map<String, double> buyRecommendations = {
    'Акции': 0,
    'Облигации': 0,
    'Золото': 0,
    'Юани': 0,
  };

  @override
  void initState() {
    super.initState();
    _fetchStockPrices();
  }

  Future<void> _fetchStockPrices() async {
    setState(() {
      _isLoading = true;
      _error = null;
      stockPrices.clear();
    });

    try {
      for (final ticker in _stockInfo.keys) {
        final url = Uri.parse(
          'https://iss.moex.com/iss/engines/stock/markets/shares/securities/$ticker.json',
        );
        final response = await http.get(url);

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final marketData = data['marketdata']['data'];

          double? lastPrice;

          if (ticker == "SBER") {
            lastPrice = marketData[2][12]?.toDouble();
          } else if (ticker == "GMKN") {
            lastPrice = marketData[2][12]?.toDouble();
          } else if (ticker == "PHOR") {
            lastPrice = marketData[1][12]?.toDouble();
          } else if (ticker == "SNGSP") {
            lastPrice = marketData[2][12]?.toDouble();
          } else if (ticker == "NVTK") {
            lastPrice = marketData[1][12]?.toDouble();
          } else if (ticker == "PLZL") {
            lastPrice = marketData[1][12]?.toDouble();
          }

          setState(() {
            stockPrices[ticker] = lastPrice;
          });
        } else {
          setState(() {
            _error = 'Ошибка сервера: ${response.statusCode}';
          });
          break;
        }
      }
    } catch (e) {
      setState(() {
        _error = 'Ошибка сети: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _calculateRebalancing() {
    FocusScope.of(context).unfocus();

    double currentStocks = double.tryParse(_currentStocksController.text) ?? 0;
    double currentBonds = double.tryParse(_currentBondsController.text) ?? 0;
    double currentGold = double.tryParse(_currentGoldController.text) ?? 0;
    double currentYan = double.tryParse(_currentYanController.text) ?? 0;
    double newFunds = double.tryParse(_newFundsController.text) ?? 0;

    double totalPortfolio =
        currentStocks + currentBonds + currentGold + currentYan + newFunds;

    // Целевые суммы для каждого актива
    double targetStocks = totalPortfolio * 0.45;
    double targetBonds = totalPortfolio * 0.25;
    double targetGold = totalPortfolio * 0.2;
    double targetYan = totalPortfolio * 0.1;

    // Сколько нужно докупить для каждого актива
    double needStocks = (targetStocks - currentStocks).clamp(
      0,
      double.infinity,
    );
    double needBonds = (targetBonds - currentBonds).clamp(0, double.infinity);
    double needGold = (targetGold - currentGold).clamp(0, double.infinity);
    double needYan = (targetYan - currentYan).clamp(0, double.infinity);

    double totalNeed = needStocks + needBonds + needGold + needYan;
    double remainingFunds = newFunds;

    // Если средств хватает - покупаем всё что нужно
    if (remainingFunds >= totalNeed) {
      setState(() {
        buyRecommendations = {
          'Акции': needStocks,
          'Облигации': needBonds,
          'Золото': needGold,
          'Юани': needYan,
        };

        _error = null;
      });
    }
    // Если средств не хватает - распределяем пропорционально целям
    else {
      // Коэффициент распределения (сколько от необходимого мы можем купить)
      double ratio = remainingFunds / totalNeed;

      setState(() {
        buyRecommendations = {
          'Акции': needStocks * ratio,
          'Облигации': needBonds * ratio,
          'Золото': needGold * ratio,
          'Юани': needYan * ratio,
        };

        _error =
            'Недостаточно средств для полной ребалансировки!\n'
            'Средства распределены пропорционально целевому распределению.\n'
            'Для полной ребалансировки нужно ещё ${(totalNeed - remainingFunds).toStringAsFixed(2)} руб.';
      });
    }

    // Обновляем фактические суммы с учетом купленного
    double actualStocks = currentStocks + buyRecommendations['Акции']!;
    double actualBonds = currentBonds + buyRecommendations['Облигации']!;
    double actualGold = currentGold + buyRecommendations['Золото']!;
    double actualYan = currentYan + buyRecommendations['Юани']!;

    // Обновляем отображение распределения
    setState(() {
      allocationResults = {
        'Акции (${(actualStocks / totalPortfolio * 100).toStringAsFixed(1)}%)':
            actualStocks,
        'Облигации (${(actualBonds / totalPortfolio * 100).toStringAsFixed(1)}%)':
            actualBonds,
        'Золото (${(actualGold / totalPortfolio * 100).toStringAsFixed(1)}%)':
            actualGold,
        'Юани (${(actualYan / totalPortfolio * 100).toStringAsFixed(1)}%)':
            actualYan,
      };
    });
  }

  void _calculateStockPurchase() {
    FocusScope.of(context).unfocus();
    double totalAmount = double.tryParse(_totalAmountController.text) ?? 0;

    stockLots.clear();
    actualAllocation.clear();
    _totalStocksCost = 0;

    for (final ticker in stocksDistribution.keys) {
      final price = stockPrices[ticker];
      if (price == null || price <= 0) continue;

      final lotSize = _stockInfo[ticker]!['lotSize'];
      final minLotCost = price * lotSize;
      final idealAmount = totalAmount * stocksDistribution[ticker]!;

      int lots = (idealAmount / minLotCost).round();
      double actualAmount = lots * minLotCost;

      stockLots[ticker] = lots;
      actualAllocation[ticker] = actualAmount;
      _totalStocksCost += actualAmount;
    }

    setState(() {});
  }

  @override
  void dispose() {
    _currentStocksController.dispose();
    _currentYanController.dispose();
    _currentBondsController.dispose();
    _currentGoldController.dispose();
    _newFundsController.dispose();
    _totalAmountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Инвестиционный калькулятор'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Ребалансировка'),
              Tab(text: 'Полный расчет'),
            ],
          ),
        ),
        body: TabBarView(
          children: [_buildRebalancingTab(), _buildFullCalculationTab()],
        ),
      ),
    );
  }

  Widget _buildRebalancingTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _currentStocksController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Текущая сумма в акциях',
              border: OutlineInputBorder(),
              suffixText: 'руб.',
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _currentBondsController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Текущая сумма в облигациях',
              border: OutlineInputBorder(),
              suffixText: 'руб.',
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _currentGoldController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Текущая сумма в золоте',
              border: OutlineInputBorder(),
              suffixText: 'руб.',
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _currentYanController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Текущая сумма в юанях',
              border: OutlineInputBorder(),
              suffixText: 'руб.',
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _newFundsController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Дополнительные средства',
              border: OutlineInputBorder(),
              suffixText: 'руб.',
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _calculateRebalancing,
            child: const Text('Рассчитать ребалансировку'),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text(
                _error!,
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
            ),
          const SizedBox(height: 20),
          if (buyRecommendations.values.any((v) => v > 0))
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Рекомендации по покупке:',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                ...buyRecommendations.entries.map((entry) {
                  if (entry.value > 0) {
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 5),
                      child: ListTile(
                        title: Text(entry.key),
                        trailing: Text(
                          '${entry.value.toStringAsFixed(2)} руб.',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    );
                  } else {
                    return const SizedBox.shrink();
                  }
                }).toList(),
              ],
            ),
          const SizedBox(height: 10),
          if (allocationResults.isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Целевое распределение:',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                ...allocationResults.entries.map(
                  (entry) => Card(
                    margin: const EdgeInsets.symmetric(vertical: 5),
                    child: ListTile(
                      title: Text(entry.key),
                      trailing: Text(
                        '${entry.value.toStringAsFixed(2)} руб.',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildFullCalculationTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _totalAmountController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Сумма на покупку акций',
              border: OutlineInputBorder(),
              suffixText: 'руб.',
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _calculateStockPurchase,
            child: const Text('Рассчитать покупки'),
          ),
          if (_isLoading) const LinearProgressIndicator(),

          const SizedBox(height: 20),
          if (stockLots.isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Рекомендованные покупки:',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                ...stockLots.entries.map((entry) {
                  final ticker = entry.key;
                  final lots = entry.value;
                  final lotSize = _stockInfo[ticker]!['lotSize'];
                  final price = stockPrices[ticker] ?? 0;
                  final name = _stockInfo[ticker]!['name'];
                  final cost = lots * lotSize * price;
                  final idealPercentage = stocksDistribution[ticker]! * 100;
                  final actualPercentage = (_totalStocksCost > 0)
                      ? (cost / _totalStocksCost) * 100
                      : 0;

                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 5),
                    child: ListTile(
                      title: Text('$name ($lots лотов)'),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Цена: ${price.toStringAsFixed(2)} руб. (лот: $lotSize шт.)',
                          ),
                          Text(
                            'Идеал: ${idealPercentage.toStringAsFixed(1)}% • Факт: ${actualPercentage.toStringAsFixed(1)}%',
                            style: TextStyle(
                              color:
                                  (actualPercentage - idealPercentage).abs() <=
                                      1
                                  ? Colors.green
                                  : Colors.orange,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      trailing: Text(
                        '${cost.toStringAsFixed(2)} руб.',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  );
                }),
                Card(
                  color: Colors.blue.shade50,
                  margin: const EdgeInsets.symmetric(vertical: 10),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      'Общая стоимость: ${_totalStocksCost.toStringAsFixed(2)} руб.',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

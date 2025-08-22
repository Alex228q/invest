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

  final TextEditingController _currentGoldController = TextEditingController();
  final TextEditingController _currentYanController = TextEditingController();
  final TextEditingController _newFundsController = TextEditingController();
  final TextEditingController _totalAmountController = TextEditingController();

  bool _isLoading = false;
  String? _error;
  double _totalStocksCost = 0;

  final Map<String, Map<String, dynamic>> _stockInfo = {
    'X5': {'name': 'X5', 'lotSize': 1, 'controller': TextEditingController()},
    'LKOH': {
      'name': 'Лукойл',
      'lotSize': 1,
      'controller': TextEditingController(),
    },
    'SBER': {
      'name': 'Сбербанк',
      'lotSize': 1,
      'controller': TextEditingController(),
    },
    'TRNFP': {
      'name': 'Транснефть',
      'lotSize': 1,
      'controller': TextEditingController(),
    },
    'PHOR': {
      'name': 'Фосагро',
      'lotSize': 1,
      'controller': TextEditingController(),
    },
  };

  Map<String, double?> stockPrices = {};
  Map<String, int> stockLots = {};
  Map<String, double> actualAllocation = {};

  final Map<String, double> stocksDistribution = {
    'X5': 0.20,
    'LKOH': 0.20,
    'SBER': 0.20,
    'TRNFP': 0.20,
    'PHOR': 0.20,
  };

  Map<String, double> allocationResults = {
    'Акции (75%)': 0,
    'Золото (15%)': 0,
    'Валюта (10%)': 0,
  };

  Map<String, double> buyRecommendations = {
    'Акции': 0,
    'Облигации': 0,
    'Золото': 0,
    'Валюта': 0,
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
          'https://iss.moex.com/iss/engines/stock/markets/shares/securities/$ticker.json?iss.meta=off',
        );
        final response = await http.get(url);

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final marketData = data['marketdata']['data'] as List;

          // Ищем первую запись, где boardid равен "TQBR" или "TQTF"
          final filteredData = marketData.firstWhere(
            (d) => ["TQBR", "TQTF"].contains(d[1]),
            orElse: () => null,
          );

          if (filteredData != null) {
            final lastPrice = filteredData[12]?.toDouble();
            setState(() {
              stockPrices[ticker] = lastPrice;
            });
          } else {
            setState(() {
              _error = 'Не найдены данные для тикера $ticker';
            });
          }
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

    double currentGold = double.tryParse(_currentGoldController.text) ?? 0;
    double currentYan = double.tryParse(_currentYanController.text) ?? 0;
    double newFunds = double.tryParse(_newFundsController.text) ?? 0;

    double totalPortfolio = currentStocks + currentGold + currentYan + newFunds;

    // Целевые суммы для каждого актива
    double targetStocks = totalPortfolio * 0.75;

    double targetGold = totalPortfolio * 0.15;
    double targetYan = totalPortfolio * 0.10;

    // Сколько нужно докупить для каждого актива
    double needStocks = (targetStocks - currentStocks).clamp(
      0,
      double.infinity,
    );

    double needGold = (targetGold - currentGold).clamp(0, double.infinity);
    double needYan = (targetYan - currentYan).clamp(0, double.infinity);

    double totalNeed = needStocks + needGold + needYan;
    double remainingFunds = newFunds;

    // Если средств хватает - покупаем всё что нужно
    if (remainingFunds >= totalNeed) {
      setState(() {
        buyRecommendations = {
          'Акции': needStocks,

          'Золото': needGold,
          'Валюта': needYan,
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

          'Золото': needGold * ratio,
          'Валюта': needYan * ratio,
        };

        _error =
            'Недостаточно средств для полной ребалансировки!\n'
            'Средства распределены пропорционально целевому распределению.\n'
            'Для полной ребалансировки нужно ещё ${(totalNeed - remainingFunds).toStringAsFixed(2)} руб.';
      });
    }

    // Обновляем фактические суммы с учетом купленного
    double actualStocks = currentStocks + buyRecommendations['Акции']!;

    double actualGold = currentGold + buyRecommendations['Золото']!;
    double actualYan = currentYan + buyRecommendations['Валюта']!;

    // Обновляем отображение распределения
    setState(() {
      allocationResults = {
        'Акции (${(actualStocks / totalPortfolio * 100).toStringAsFixed(1)}%)':
            actualStocks,

        'Золото (${(actualGold / totalPortfolio * 100).toStringAsFixed(1)}%)':
            actualGold,
        'Валюта (${(actualYan / totalPortfolio * 100).toStringAsFixed(1)}%)':
            actualYan,
      };
    });
  }

  void _calculateStockPurchase() {
    FocusScope.of(context).unfocus();
    double totalAmount = double.tryParse(_totalAmountController.text) ?? 0;

    // Получаем суммы уже купленных акций
    Map<String, double> currentInvestments = {};
    for (var entry in _stockInfo.entries) {
      double value = double.tryParse(entry.value['controller'].text) ?? 0;
      currentInvestments[entry.key] = value;
    }

    // Рассчитываем общую сумму текущих инвестиций
    double totalCurrentInvestments = currentInvestments.values.fold(
      0,
      (sum, value) => sum + value,
    );

    stockLots.clear();
    actualAllocation.clear();
    _totalStocksCost = 0;
    double remainingAmount = totalAmount;

    // Рассчитываем дефицит для каждой акции
    Map<String, double> deficit = {};
    double totalDeficit = 0;

    for (var entry in stocksDistribution.entries) {
      final ticker = entry.key;
      final targetFraction = entry.value;

      // Целевая сумма с учетом текущих инвестиций и новых средств
      double targetAmount =
          (totalCurrentInvestments + totalAmount) * targetFraction;

      // Текущие инвестиции в эту акцию
      double currentAmount = currentInvestments[ticker] ?? 0;

      // Дефицит = сколько нужно докупить до целевой суммы
      double tickerDeficit = (targetAmount - currentAmount).clamp(
        0,
        double.infinity,
      );

      deficit[ticker] = tickerDeficit;
      totalDeficit += tickerDeficit;
    }

    // Распределение средств пропорционально дефициту
    if (totalDeficit > 0) {
      for (var entry in deficit.entries) {
        final ticker = entry.key;
        final price = stockPrices[ticker];
        if (price == null || price <= 0) continue;

        final lotSize = _stockInfo[ticker]!['lotSize'];
        final minLotCost = price * lotSize;

        // Пропорция для этой акции
        double proportion = entry.value / totalDeficit;

        // Сумма для инвестирования в эту акцию
        double amountForTicker = totalAmount * proportion;

        // Покупаем целое количество лотов
        int lots = (amountForTicker / minLotCost).floor();
        if (lots > 0) {
          double actualAmount = lots * minLotCost;

          stockLots[ticker] = lots;
          actualAllocation[ticker] = actualAmount;
          _totalStocksCost += actualAmount;
          remainingAmount -= actualAmount;
        }
      }
    }

    // Распределение остатка (если есть)
    if (remainingAmount > 0) {
      // Сортируем акции по отклонению от целевой доли (наибольшее отклонение в начале)
      var sortedByDeviation = stocksDistribution.entries.toList()
        ..sort((a, b) {
          double currentA =
              (actualAllocation[a.key] ?? 0) + (currentInvestments[a.key] ?? 0);
          double currentB =
              (actualAllocation[b.key] ?? 0) + (currentInvestments[b.key] ?? 0);
          double targetA = (totalCurrentInvestments + totalAmount) * a.value;
          double targetB = (totalCurrentInvestments + totalAmount) * b.value;

          double deviationA = (targetA - currentA) / targetA;
          double deviationB = (targetB - currentB) / targetB;

          return deviationB.compareTo(deviationA);
        });

      // Покупаем лоты для акций с наибольшим отклонением
      for (var entry in sortedByDeviation) {
        final ticker = entry.key;
        final price = stockPrices[ticker];
        if (price == null || price <= 0 || remainingAmount <= 0) continue;

        final lotSize = _stockInfo[ticker]!['lotSize'];
        final minLotCost = price * lotSize;

        if (remainingAmount >= minLotCost) {
          int additionalLots = (remainingAmount / minLotCost).floor();
          if (additionalLots > 0) {
            double additionalAmount = additionalLots * minLotCost;

            stockLots[ticker] = (stockLots[ticker] ?? 0) + additionalLots;
            actualAllocation[ticker] =
                (actualAllocation[ticker] ?? 0) + additionalAmount;
            _totalStocksCost += additionalAmount;
            remainingAmount -= additionalAmount;
          }
        }
      }
    }

    setState(() {});
  }

  @override
  void dispose() {
    _currentStocksController.dispose();
    _currentYanController.dispose();
    _currentGoldController.dispose();
    _newFundsController.dispose();
    _totalAmountController.dispose();
    for (var entry in _stockInfo.entries) {
      entry.value['controller'].dispose();
    }
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
              labelText: 'Текущая сумма в валюте',
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
    // Рассчитываем общую сумму текущих инвестиций
    double totalCurrentInvestments = 0;
    for (var entry in _stockInfo.entries) {
      totalCurrentInvestments +=
          double.tryParse(entry.value['controller'].text) ?? 0;
    }

    // Общая стоимость портфеля акций после покупки
    double totalPortfolioAfter = totalCurrentInvestments + _totalStocksCost;

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
          const Text(
            'Уже купленные акции:',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          ..._stockInfo.entries.map((entry) {
            final ticker = entry.key;
            final name = entry.value['name'];
            final controller =
                entry.value['controller'] as TextEditingController;

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: name,
                  border: const OutlineInputBorder(),
                  suffixText: 'руб.',
                ),
              ),
            );
          }),
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

                  // Сумма старых инвестиций в эту акцию
                  double currentAmount =
                      double.tryParse(_stockInfo[ticker]!['controller'].text) ??
                      0;

                  // Целевой процент
                  final idealPercentage = stocksDistribution[ticker]! * 100;

                  // Фактический процент ПОСЛЕ покупки
                  double actualPercentage = totalPortfolioAfter > 0
                      ? ((currentAmount + cost) / totalPortfolioAfter * 100)
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
                          Text(
                            'Текущие: ${currentAmount.toStringAsFixed(0)} руб. • Новые: ${cost.toStringAsFixed(0)} руб.',
                            style: const TextStyle(fontSize: 12),
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
                    child: Column(
                      children: [
                        Text(
                          'Стоимость новых покупок: ${_totalStocksCost.toStringAsFixed(2)} руб.',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Общая стоимость портфеля акций: ${totalPortfolioAfter.toStringAsFixed(2)} руб.',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                        if (totalCurrentInvestments > 0) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Текущие инвестиции: ${totalCurrentInvestments.toStringAsFixed(2)} руб.',
                            style: const TextStyle(fontSize: 14),
                          ),
                        ],
                      ],
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

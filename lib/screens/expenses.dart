import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:book_tracker/widgets/drawer.dart';

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});

  @override
  _ExpensesScreenState createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  String? selectedMonth;
  String? selectedYear;
  double totalExpenses = 0.0;
  double monthlyBudget = 0.0;
  final List<String> monthsOfYear = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  List<String> availableYears = [];
  final TextEditingController budgetController = TextEditingController();

  @override
  void initState() {
    super.initState();
    selectedMonth = monthsOfYear[DateTime.now().month - 1];
    selectedYear = DateTime.now().year.toString();
    fetchAvailableYears();
    fetchBudget();
  }

  // Fetch the available years when the user has books in their collection
  Future<void> fetchAvailableYears() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      showDialog(
        context: context,
        builder: (context) {
          return const AlertDialog(
            title: Text('Error'),
            content: Text('No user is logged in.'),
          );
        },
      );
      return;
    }

    final userBooksCollection = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('books');

    final QuerySnapshot booksSnapshot = await userBooksCollection.get();
    final years = <String>{};

    for (var doc in booksSnapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final buyDateTimestamp = data['buyDate'] as Timestamp?;

      if (buyDateTimestamp != null) {
        final buyDate = buyDateTimestamp.toDate();
        years.add(buyDate.year.toString());
      }
    }

    setState(() {
      availableYears = years.toList()..sort();
      selectedYear ??= availableYears.isNotEmpty ? availableYears.first : null;
      calculateTotalExpensesForMonth();
    });
  }

  // Fetch the user's monthly budget from Firebase
  Future<void> fetchBudget() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      showDialog(
        context: context,
        builder: (context) {
          return const AlertDialog(
            title: Text('Error'),
            content: Text('No user is logged in.'),
          );
        },
      );
      return;
    }

    final userDoc =
        FirebaseFirestore.instance.collection('users').doc(user.uid);
    final userSnapshot = await userDoc.get();
    final data = userSnapshot.data();
    if (data != null && data['monthlyBudget'] != null) {
      setState(() {
        monthlyBudget = data['monthlyBudget'].toDouble();
        budgetController.text =
            monthlyBudget.toStringAsFixed(0); // Remove .0 from display
      });
    }
  }

  // Save the user's monthly budget to Firebase as the user types
  Future<void> saveBudget(String value) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      showDialog(
        context: context,
        builder: (context) {
          return const AlertDialog(
            title: Text('Error'),
            content: Text('No user is logged in.'),
          );
        },
      );
      return;
    }

    final budget = double.tryParse(value) ?? 0.0;
    final userDoc =
        FirebaseFirestore.instance.collection('users').doc(user.uid);

    await userDoc.update({
      'monthlyBudget': budget,
    });

    setState(() {
      monthlyBudget = budget;
      budgetController.text =
          budget.toStringAsFixed(0); // Remove .0 from display
    });

    // Recalculate expenses after updating budget
    calculateTotalExpensesForMonth();
  }

  // Calculate total expenses for the selected month
  Future<void> calculateTotalExpensesForMonth() async {
    if (selectedMonth == null || selectedYear == null) return;

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      showDialog(
        context: context,
        builder: (context) {
          return const AlertDialog(
            title: Text('Error'),
            content: Text('No user is logged in.'),
          );
        },
      );
      return;
    }

    final userBooksCollection = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('books');

    final QuerySnapshot booksSnapshot = await userBooksCollection.get();

    double total = 0.0;
    for (var doc in booksSnapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final price = double.tryParse(data['price'] ?? '0') ?? 0;
      final buyDateTimestamp = data['buyDate'] as Timestamp?;

      if (buyDateTimestamp != null) {
        final buyDate = buyDateTimestamp.toDate();
        final monthName = monthsOfYear[buyDate.month - 1];

        if (monthName == selectedMonth &&
            buyDate.year.toString() == selectedYear) {
          total += price;
        }
      }
    }

    setState(() {
      totalExpenses = total;
    });
  }

  // Format double values to remove .0 if it is an integer
  String formatAmount(double amount) {
    return amount == amount.toInt()
        ? amount.toInt().toString()
        : amount.toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    bool isOverBudget = totalExpenses > monthlyBudget;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Expenses'),
      ),
      drawer: const CustomDrawer(),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Set Monthly Budget',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: budgetController,
              decoration: const InputDecoration(
                labelText: 'Monthly Budget',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              onChanged: (value) {
                saveBudget(value); // Save budget automatically as user types
              },
              onSubmitted: (value) {
                saveBudget(value); // Save budget when the user submits
              },
            ),
            const SizedBox(height: 16),
            const Text(
              'Select Month and Year',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                // Month Dropdown
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: selectedMonth,
                    decoration: const InputDecoration(
                      labelText: 'Month',
                      border: OutlineInputBorder(),
                    ),
                    items: monthsOfYear.map((month) {
                      return DropdownMenuItem(
                        value: month,
                        child: Text(month),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedMonth = value;
                        calculateTotalExpensesForMonth();
                      });
                    },
                  ),
                ),
                const SizedBox(width: 16),
                // Year Dropdown
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: selectedYear,
                    decoration: const InputDecoration(
                      labelText: 'Year',
                      border: OutlineInputBorder(),
                    ),
                    items: availableYears.map((year) {
                      return DropdownMenuItem(
                        value: year,
                        child: Text(year),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedYear = value;
                        calculateTotalExpensesForMonth();
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            // Donut Chart
            AspectRatio(
              aspectRatio: 1,
              child: PieChart(
                PieChartData(
                  sections: [
                    PieChartSectionData(
                      value: totalExpenses,
                      title: 'Rp ${formatAmount(totalExpenses)}',
                      color: isOverBudget
                          ? Colors.red
                          : Colors.blue, // Red if over budget
                      radius: 60,
                    ),
                    PieChartSectionData(
                      value: monthlyBudget - totalExpenses,
                      title:
                          'Rp ${formatAmount(monthlyBudget - totalExpenses)}',
                      color: isOverBudget
                          ? Colors.red.withOpacity(0.4)
                          : Colors.grey, // Red if over budget
                      radius: 60,
                    ),
                  ],
                  borderData: FlBorderData(show: false),
                  centerSpaceRadius: 50,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Total Expenses: Rp ${formatAmount(totalExpenses)}',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Remaining Budget: Rp ${formatAmount(monthlyBudget - totalExpenses)}',
              style: TextStyle(
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

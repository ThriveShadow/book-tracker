import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:book_tracker/widgets/my_button.dart';
import 'package:simple_barcode_scanner/simple_barcode_scanner.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class AddBookScreen extends StatefulWidget {
  const AddBookScreen({super.key});

  @override
  AddBookScreenState createState() => AddBookScreenState();
}

class AddBookScreenState extends State<AddBookScreen> {
  final titleController = TextEditingController();
  final authorController = TextEditingController();
  final statusController = TextEditingController();
  final noteController = TextEditingController();
  final priceController = TextEditingController();
  DateTime? buyDate;
  String result = '';

  @override
  void dispose() {
    titleController.dispose();
    authorController.dispose();
    statusController.dispose();
    noteController.dispose();
    priceController.dispose();
    super.dispose();
  }

  Future<void> fetchBookInfo(String isbn) async {
    final url =
        Uri.parse('https://www.googleapis.com/books/v1/volumes?q=isbn:$isbn');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      if (data != null && data['items'] != null && data['items'].isNotEmpty) {
        titleController.text = data['items'][0]['volumeInfo']['title'];
        authorController.text = data['items'][0]['volumeInfo']['authors'][0];
      } else {
        print('No data found from Google Books API. Trying Perpusnas API...');

        try {
          final fallbackUrl = Uri.parse(
              'https://isbn.perpusnas.go.id/Account/GetBuku?kd1=ISBN&kd2=$isbn&limit=10&offset=0');
          final fallbackResponse = await http.get(fallbackUrl);

          print(fallbackResponse.statusCode);

          if (fallbackResponse.statusCode == 200) {
            final fallbackData = jsonDecode(fallbackResponse.body);
            print(fallbackData);

            if (fallbackData != null &&
                fallbackData['rows'] != null &&
                fallbackData['rows'].isNotEmpty) {
              titleController.text = fallbackData['rows'][0]['Judul'];
              authorController.text = fallbackData['rows'][0]['Pengarang'];
            }
          }
        } catch (e) {
          print('Error fetching data from Perpusnas API: $e');
        }
      }
    }
  }

  Future<void> selectBuyDate(BuildContext context) async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (pickedDate != null && pickedDate != buyDate) {
      setState(() {
        buyDate = pickedDate;
      });
    }
  }

  void addBook() async {
    final title = titleController.text;
    final author = authorController.text;
    final status =
        statusController.text.isEmpty ? 'Owned' : statusController.text;
    final note = noteController.text;
    final price = priceController.text;
    final isbn = result;

    if (title.isEmpty || status.isEmpty) {
      showDialog(
        context: context,
        builder: (context) {
          return const AlertDialog(
            title: Text('Invalid Input'),
            content: Text('Title and status are required.'),
          );
        },
      );
      return;
    }

    // Get the current user
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

    await userDoc.collection('books').add({
      'title': title,
      'author': author,
      'status': status,
      'note': note,
      'price': price,
      'isbn': isbn,
      'createdAt': FieldValue.serverTimestamp(),
      'buyDate': buyDate,
    });

    // Pop the screen after adding the book
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Book'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(
                  labelText: 'Title*', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: authorController,
              decoration: const InputDecoration(
                  labelText: 'Author', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () => selectBuyDate(context),
              child: AbsorbPointer(
                child: TextField(
                  controller: TextEditingController(
                      text: buyDate != null
                          ? '${buyDate!.day}/${buyDate!.month}/${buyDate!.year}'
                          : ''),
                  decoration: InputDecoration(
                    labelText: 'Buy Date',
                    border: const OutlineInputBorder(),
                    hintText: buyDate != null
                        ? '${buyDate!.day}-${buyDate!.month}-${buyDate!.year}'
                        : 'Select a date',
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: priceController,
                    decoration: const InputDecoration(
                        labelText: 'Price', border: OutlineInputBorder()),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: statusController.text.isEmpty
                        ? 'Owned'
                        : statusController.text,
                    decoration: const InputDecoration(
                        labelText: 'Status*', border: OutlineInputBorder()),
                    items: const [
                      DropdownMenuItem(value: 'Owned', child: Text('Owned')),
                      DropdownMenuItem(
                          value: 'Wishlist', child: Text('Wishlist')),
                    ],
                    onChanged: (value) {
                      setState(() {
                        statusController.text = value!;
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: noteController,
              decoration: const InputDecoration(
                  labelText: 'Note',
                  border: OutlineInputBorder(),
                  hintText: 'e.g. Tags, Buy location, etc.'),
              maxLines: 5,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                String? res = await SimpleBarcodeScanner.scanBarcode(
                  context,
                  barcodeAppBar: const BarcodeAppBar(
                    appBarTitle: 'Test',
                    centerTitle: false,
                    enableBackButton: true,
                    backButtonIcon: Icon(Icons.arrow_back_ios),
                  ),
                  isShowFlashIcon: true,
                  delayMillis: 500,
                  cameraFace: CameraFace.back,
                  scanFormat: ScanFormat.ONLY_BARCODE,
                );
                setState(() {
                  result = res as String;
                  fetchBookInfo(result);
                });
              },
              child: const Text('Scan Barcode'),
            ),
            const SizedBox(
              height: 10,
            ),
            Text('Scan Barcode Result: $result'),
            const SizedBox(
              height: 10,
            ),
            const Spacer(),
            MyButton(
              buttonText: 'Add Book!',
              onTap: addBook,
            ),
          ],
        ),
      ),
    );
  }
}

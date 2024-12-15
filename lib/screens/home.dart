import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:book_tracker/screens/auth.dart';
import 'package:book_tracker/screens/new_book.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _searchQuery = "";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        leading: Builder(
          builder: (BuildContext context) {
            return IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () {
                Scaffold.of(context).openDrawer();
              },
            );
          },
        ),
      ),
      drawer: Drawer(
        child: Column(
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(
                color: Colors.deepPurple,
              ),
              child: Center(
                child: Text(
                  'Book Tracker',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                  ),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.home),
              title: const Text('Home'),
              onTap: () {
                Navigator.of(context).pushNamed('/home');
              },
            ),
            ListTile(
              leading: const Icon(Icons.attach_money),
              title: const Text('Expenses'),
              onTap: () {
                Navigator.of(context).pushNamed('/expenses');
              },
            ),
            const Spacer(),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Logout'),
              onTap: () async {
                final navigator = Navigator.of(context);
                await FirebaseAuth.instance.signOut();
                if (mounted) {
                  navigator.pushReplacement(
                    MaterialPageRoute(
                      builder: (context) => const AuthScreen(),
                    ),
                  );
                }
              },
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
              decoration: InputDecoration(
                hintText: 'Search books...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(FirebaseAuth.instance.currentUser?.uid)
                  .collection('books')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return const Center(child: Text('Error loading books'));
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                      child: Text('No books found. Add a book!'));
                }

                var books = snapshot.data!.docs;

                // Filter books based on search query
                books = books.where((book) {
                  final bookData = book.data() as Map<String, dynamic>;
                  final title = (bookData['title'] ?? '').toLowerCase();
                  return title.contains(_searchQuery);
                }).toList();

                books.sort((a, b) {
                  final aData = a.data() as Map<String, dynamic>;
                  final bData = b.data() as Map<String, dynamic>;
                  final aDate = aData['createdAt'] as Timestamp;
                  final bDate = bData['createdAt'] != null
                      ? bData['createdAt'] as Timestamp
                      : Timestamp.now();
                  return bDate.compareTo(aDate);
                });

                return ListView.builder(
                  itemCount: books.length,
                  itemBuilder: (context, index) {
                    final book = books[index];
                    final bookData = book.data() as Map<String, dynamic>;
                    return Card(
                      margin: const EdgeInsets.all(8),
                      child: ListTile(
                        title: Text(bookData['title'] ?? 'No Title'),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(bookData['author'] ?? 'Unknown'),
                            Text(bookData['createdAt'] != null
                                ? DateFormat('dd MMMM yyyy').format(
                                    (bookData['createdAt'] as Timestamp)
                                        .toDate())
                                : 'No Date'),
                          ],
                        ),
                        trailing: Text(bookData['status'] ?? 'Unknown'),
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (context) {
                              return AlertDialog(
                                title: Text(bookData['title'] ?? 'No Title'),
                                content: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                        'Author: ${bookData['author'] ?? 'Unknown'}'),
                                    Text(
                                        'Status: ${bookData['status'] ?? 'Unknown'}'),
                                    Text(
                                        'Note: ${bookData['note'] ?? 'Unknown'}'),
                                    Text(
                                        'Price: ${bookData['price'] ?? 'Unknown'}'),
                                  ],
                                ),
                                actions: [
                                  ElevatedButton(
                                    onPressed: () async {
                                      final navigator = Navigator.of(context);
                                      await book.reference.delete();
                                      if (mounted) {
                                        navigator.pop();
                                      }
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red,
                                    ),
                                    child: const Text('Delete'),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      Navigator.of(context).pop();
                                    },
                                    child: const Text('Close'),
                                  ),
                                ],
                              );
                            },
                          );
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const AddBookScreen(),
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

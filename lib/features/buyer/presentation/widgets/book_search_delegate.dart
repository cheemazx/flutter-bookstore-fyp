
import 'package:flutter/material.dart';
import '../../../../core/models/book.dart';
import 'package:go_router/go_router.dart';

class BookSearchDelegate extends SearchDelegate {
  final List<Book> books;

  BookSearchDelegate(this.books);

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () {
          query = '';
        },
      ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () {
        close(context, null);
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildList(context);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _buildList(context);
  }

  Widget _buildList(BuildContext context) {
    final results = books.where((book) {
      return book.title.toLowerCase().contains(query.toLowerCase()) ||
          book.author.toLowerCase().contains(query.toLowerCase()) ||
          book.genre.toLowerCase().contains(query.toLowerCase());
    }).toList();

    return ListView.builder(
      itemCount: results.length,
      itemBuilder: (context, index) {
        final book = results[index];
        return ListTile(
          leading: Image.network(
            book.imageUrl, 
            width: 40, 
            fit: BoxFit.cover,
            errorBuilder: (c, e, s) => Container(color: Colors.grey[300], width: 40, height: 60, child: const Icon(Icons.book, size: 20)),
          ),
          title: Text(book.title, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(book.author, maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.deepPurple[50],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      book.genre,
                      style: const TextStyle(
                        color: Colors.deepPurple,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Rs. ${book.price.toStringAsFixed(2)}',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
          onTap: () {
            close(context, null);
            context.push('/product-details/${book.id}');
          },
        );
      },
    );
  }
}

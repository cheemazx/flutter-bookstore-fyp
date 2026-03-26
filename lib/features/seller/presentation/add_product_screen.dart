import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/models/book.dart';
import '../../../core/providers/inventory_provider.dart';
import '../../../../core/repositories/storage_repository.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/data/user_repository.dart';
import 'widgets/product_images_widget.dart';

class AddProductScreen extends ConsumerStatefulWidget {
  final Book? bookToEdit;
  const AddProductScreen({super.key, this.bookToEdit});

  @override
  ConsumerState<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends ConsumerState<AddProductScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _authorController;
  late TextEditingController _priceController;
  late TextEditingController _quantityController;
  late TextEditingController _descriptionController;

  String _selectedGenre = 'Fiction';
  final List<String> _genreOptions = [
    'Fiction',
    'Non-fiction',
    'Mystery',
    'Fantasy',
    'Science Fiction',
    'Biography',
    'History',
    'Romance',
    'Thriller',
    'Technology',
    'Children',
  ];
  
  List<XFile> _newImages = [];
  List<String> _existingImageUrls = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.bookToEdit?.title ?? '');
    _authorController = TextEditingController(text: widget.bookToEdit?.author ?? '');
    _priceController = TextEditingController(text: widget.bookToEdit?.price.toString() ?? '');
    _quantityController = TextEditingController(text: widget.bookToEdit?.quantity.toString() ?? '1');
    _descriptionController = TextEditingController(text: widget.bookToEdit?.description ?? '');
    
    if (widget.bookToEdit != null && _genreOptions.contains(widget.bookToEdit!.genre)) {
      _selectedGenre = widget.bookToEdit!.genre;
    }
    _existingImageUrls = widget.bookToEdit?.imageUrls ?? [];
  }

  @override
  void dispose() {
    _titleController.dispose();
    _authorController.dispose();
    _priceController.dispose();
    _quantityController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_newImages.isEmpty && _existingImageUrls.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one image')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Fetch current user data for sellerId and storeName
      final currentUser = ref.read(authRepositoryProvider).currentUser;
      if (currentUser == null) throw Exception('User not logged in');
      
      final userProfile = await ref.read(userRepositoryProvider).getUser(currentUser.id);
      final sellerId = currentUser.id;
      final storeName = userProfile?.name ?? 'Unknown Seller';

      // 1. Upload new images
      final newUrls = await ref.read(storageRepositoryProvider).uploadImages(_newImages);
      final allUrls = [..._existingImageUrls, ...newUrls];

      final title = _titleController.text;
      final author = _authorController.text;
      final price = double.tryParse(_priceController.text) ?? 0.0;
      final quantity = int.tryParse(_quantityController.text) ?? 1;
      final genre = _selectedGenre;
      final description = _descriptionController.text;
      final isEditing = widget.bookToEdit != null;

      if (isEditing) {
        final updatedBook = Book(
          id: widget.bookToEdit!.id,
          title: title,
          author: author,
          price: price,
          imageUrls: allUrls,
          description: description,
          sellerId: widget.bookToEdit!.sellerId, // Keep original sellerId
          storeName: widget.bookToEdit!.storeName, // Keep original storeName or update if needed? Usually store name updates propagate via profile, but here we persist snapshot.
          quantity: quantity,
          genre: genre,
        );
        await ref.read(inventoryProvider.notifier).updateBook(updatedBook);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Book Updated!')),
          );
        }
      } else {
        final newBook = Book(
          id: '', // Notifier will generate
          title: title,
          author: author,
          price: price,
          imageUrls: allUrls,
          description: description,
          sellerId: sellerId,
          storeName: storeName,
          quantity: quantity,
          genre: genre,
        );
        await ref.read(inventoryProvider.notifier).addBook(newBook);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Book Added!')),
          );
        }
      }
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.bookToEdit != null;

    return Scaffold(
      appBar: AppBar(title: Text(isEditing ? 'Edit Book' : 'Add New Book')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ProductImagesWidget(
                initialImages: _newImages,
                existingImageUrls: _existingImageUrls,
                onImagesSelected: (images) {
                  setState(() {
                    _newImages.addAll(images);
                  });
                },
                onUrlRemoved: (url) {
                  setState(() {
                    _existingImageUrls.remove(url);
                  });
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Book Title',
                  prefixIcon: Icon(Icons.book),
                ),
                validator: (value) =>
                    value!.isEmpty ? 'Please enter title' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _authorController,
                decoration: const InputDecoration(
                  labelText: 'Author',
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (value) =>
                    value!.isEmpty ? 'Please enter author' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _priceController,
                decoration: const InputDecoration(
                  labelText: 'Price',
                  prefixIcon: Icon(Icons.attach_money),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Required';
                  if (double.tryParse(value) == null) return 'Invalid number';
                  return null;
                },
              ),
              const SizedBox(height: 16),
               Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedGenre,
                      isExpanded: true, // Fix overflow by allowing dropdown to expand and constrain text
                      decoration: const InputDecoration(
                        labelText: 'Genre',
                        prefixIcon: Icon(Icons.category),
                      ),
                      items: _genreOptions.map((String genre) {
                        return DropdownMenuItem<String>(
                          value: genre,
                          child: Text(
                            genre,
                            overflow: TextOverflow.ellipsis, // Truncate text if too long
                          ),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          setState(() {
                            _selectedGenre = newValue;
                          });
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _quantityController,
                      decoration: const InputDecoration(
                        labelText: 'Quantity',
                        prefixIcon: Icon(Icons.inventory),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Required';
                        if (int.tryParse(value) == null) return 'Invalid number';
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
               TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  prefixIcon: Icon(Icons.description),
                ),
                maxLines: 3,
                validator: (value) =>
                    value!.isEmpty ? 'Please enter description' : null,
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _isLoading ? null : _saveProduct,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading ? const CircularProgressIndicator() : Text(isEditing ? 'Update Book' : 'Add Book'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

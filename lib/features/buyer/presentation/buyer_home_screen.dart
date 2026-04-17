import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/models/book.dart';
import '../../../../core/theme/app_theme.dart';
import '../../seller/data/all_books_provider.dart';
import 'widgets/book_card.dart';
import 'widgets/book_search_delegate.dart';

enum SortOption {
  relevance,
  priceLowToHigh,
  priceHighToLow,
  ratingLowToHigh,
  ratingHighToLow,
}

class BuyerHomeScreen extends ConsumerStatefulWidget {
  const BuyerHomeScreen({super.key});

  @override
  ConsumerState<BuyerHomeScreen> createState() => _BuyerHomeScreenState();
}

class _BuyerHomeScreenState extends ConsumerState<BuyerHomeScreen> {
  SortOption _currentSortOption = SortOption.relevance;
  String _selectedGenre = 'All';
  RangeValues _selectedPriceRange = const RangeValues(0, 500);
  double _minRating = 0;
  List<String> _selectedGenres = [];

  List<Book> _processBooks(List<Book> books) {
    if (books.isEmpty) return [];

    var filteredBooks = books.where((book) {
      // Genre chip filter
      if (_selectedGenre != 'All' && book.genre != _selectedGenre) {
        return false;
      }
      // Advanced genre filter
      if (_selectedGenres.isNotEmpty && !_selectedGenres.contains(book.genre)) {
        return false;
      }
      if (book.price < _selectedPriceRange.start || book.price > _selectedPriceRange.end) {
        return false;
      }
      if (book.rating < _minRating) {
        return false;
      }
      return true;
    }).toList();

    final sortedBooks = List<Book>.from(filteredBooks);
    switch (_currentSortOption) {
      case SortOption.priceLowToHigh:
        sortedBooks.sort((a, b) => a.price.compareTo(b.price));
        break;
      case SortOption.priceHighToLow:
        sortedBooks.sort((a, b) => b.price.compareTo(a.price));
        break;
      case SortOption.ratingLowToHigh:
        sortedBooks.sort((a, b) => a.rating.compareTo(b.rating));
        break;
      case SortOption.ratingHighToLow:
        sortedBooks.sort((a, b) => b.rating.compareTo(a.rating));
        break;
      case SortOption.relevance:
      default:
        break;
    }
    return sortedBooks;
  }

  void _showFilterModal(BuildContext context, List<Book> allBooks) {
    double maxPrice = 100;
    if (allBooks.isNotEmpty) {
      final maxBookPrice = allBooks.map((e) => e.price).reduce((a, b) => a > b ? a : b);
      maxPrice = (maxBookPrice / 10).ceil() * 10.0 + 10;
    }

    final allGenres = allBooks.map((e) => e.genre).toSet().toList()..sort();
    RangeValues tempPriceRange = _selectedPriceRange;
    if (tempPriceRange.end > maxPrice) {
      tempPriceRange = RangeValues(tempPriceRange.start, maxPrice);
    }
    double tempMinRating = _minRating;
    List<String> tempSelectedGenres = List.from(_selectedGenres);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.7,
              minChildSize: 0.5,
              maxChildSize: 0.95,
              expand: false,
              builder: (context, scrollController) {
                return Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40, height: 4,
                          decoration: BoxDecoration(
                            color: const Color(0xFFD1D5DB),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Filters', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
                          TextButton(
                            onPressed: () {
                              setModalState(() {
                                tempPriceRange = RangeValues(0, maxPrice);
                                tempMinRating = 0;
                                tempSelectedGenres = [];
                              });
                            },
                            child: const Text('Reset'),
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      Expanded(
                        child: ListView(
                          controller: scrollController,
                          children: [
                            const Text('Price Range', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                            const SizedBox(height: 8),
                            RangeSlider(
                              values: tempPriceRange,
                              min: 0,
                              max: maxPrice,
                              divisions: 20,
                              activeColor: AppTheme.primary,
                              labels: RangeLabels(
                                'Rs. ${tempPriceRange.start.round()}',
                                'Rs. ${tempPriceRange.end.round()}',
                              ),
                              onChanged: (RangeValues values) {
                                setModalState(() => tempPriceRange = values);
                              },
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Rs. ${tempPriceRange.start.toStringAsFixed(0)}', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                                Text('Rs. ${tempPriceRange.end.toStringAsFixed(0)}', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                              ],
                            ),
                            const SizedBox(height: 24),
                            const Text('Minimum Rating', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                            const SizedBox(height: 8),
                            Slider(
                              value: tempMinRating, min: 0, max: 5, divisions: 5,
                              activeColor: AppTheme.primary,
                              label: tempMinRating.toString(),
                              onChanged: (value) {
                                setModalState(() => tempMinRating = value);
                              },
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Any', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                                Text('${tempMinRating.toInt()}+ Stars', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                                const Text('5 Stars', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                              ],
                            ),
                            const SizedBox(height: 24),
                            const Text('Genres', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8, runSpacing: 8,
                              children: allGenres.map((genre) {
                                final isSelected = tempSelectedGenres.contains(genre);
                                return FilterChip(
                                  label: Text(genre),
                                  selected: isSelected,
                                  selectedColor: AppTheme.primary.withValues(alpha: 0.12),
                                  checkmarkColor: AppTheme.primary,
                                  onSelected: (bool selected) {
                                    setModalState(() {
                                      if (selected) {
                                        tempSelectedGenres.add(genre);
                                      } else {
                                        tempSelectedGenres.remove(genre);
                                      }
                                    });
                                  },
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _selectedPriceRange = tempPriceRange;
                              _minRating = tempMinRating;
                              _selectedGenres = tempSelectedGenres;
                            });
                            Navigator.pop(context);
                          },
                          child: const Text('Apply Filters'),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final booksAsync = ref.watch(allBooksProvider);

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/chatbot'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primary.withValues(alpha: 0.35),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(Icons.auto_awesome, color: Colors.white, size: 24),
        ),
      ),
      body: SafeArea(
        child: booksAsync.when(
          data: (books) {
            final allGenres = ['All', ...books.map((e) => e.genre).toSet().toList()..sort()];
            final processedBooks = _processBooks(books);

            return CustomScrollView(
              slivers: [
                // ── Header ──
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Bookstore',
                                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Discover your next great read',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        _buildIconButton(Icons.person_outline, () => context.push('/buyer-profile')),
                        const SizedBox(width: 8),
                        _buildIconButton(Icons.shopping_bag_outlined, () => context.push('/cart')),
                      ],
                    ),
                  ),
                ),

                // ── Search Bar ──
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                    child: GestureDetector(
                      onTap: () {
                        showSearch(
                          context: context,
                          delegate: BookSearchDelegate(books),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.03),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.search_rounded, color: AppTheme.textLight, size: 22),
                            const SizedBox(width: 12),
                            Text(
                              'Search books, authors...',
                              style: TextStyle(color: AppTheme.textLight, fontSize: 14),
                            ),
                            const Spacer(),
                            GestureDetector(
                              onTap: () => _showFilterModal(context, books),
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: AppTheme.primary.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(Icons.tune_rounded, color: AppTheme.primary, size: 18),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // ── Genre Chips ──
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 52,
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                      scrollDirection: Axis.horizontal,
                      itemCount: allGenres.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final genre = allGenres[index];
                        final isSelected = _selectedGenre == genre;
                        return GestureDetector(
                          onTap: () => setState(() => _selectedGenre = genre),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected ? AppTheme.primary : Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isSelected ? AppTheme.primary : const Color(0xFFE5E7EB),
                              ),
                              boxShadow: isSelected
                                  ? [BoxShadow(color: AppTheme.primary.withValues(alpha: 0.25), blurRadius: 8, offset: const Offset(0, 2))]
                                  : [],
                            ),
                            child: Center(
                              child: Text(
                                genre,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: isSelected ? Colors.white : AppTheme.textSecondary,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),

                // ── Sort Row ──
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${processedBooks.length} books found',
                          style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary, fontWeight: FontWeight.w500),
                        ),
                        PopupMenuButton<SortOption>(
                          icon: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.sort_rounded, size: 18, color: AppTheme.primary),
                              const SizedBox(width: 4),
                              Text('Sort', style: TextStyle(fontSize: 13, color: AppTheme.primary, fontWeight: FontWeight.w600)),
                            ],
                          ),
                          onSelected: (SortOption result) {
                            setState(() => _currentSortOption = result);
                          },
                          itemBuilder: (BuildContext context) => <PopupMenuEntry<SortOption>>[
                            const PopupMenuItem<SortOption>(value: SortOption.relevance, child: Text('Relevance')),
                            const PopupMenuItem<SortOption>(value: SortOption.priceLowToHigh, child: Text('Price: Low to High')),
                            const PopupMenuItem<SortOption>(value: SortOption.priceHighToLow, child: Text('Price: High to Low')),
                            const PopupMenuItem<SortOption>(value: SortOption.ratingHighToLow, child: Text('Rating: High to Low')),
                            const PopupMenuItem<SortOption>(value: SortOption.ratingLowToHigh, child: Text('Rating: Low to High')),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Book Grid or Empty State ──
                if (processedBooks.isEmpty)
                  SliverFillRemaining(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: Icon(Icons.search_off_rounded, size: 40, color: AppTheme.primary.withValues(alpha: 0.5)),
                          ),
                          const SizedBox(height: 20),
                          const Text('No books found', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                          const SizedBox(height: 8),
                          const Text('Try adjusting your filters', style: TextStyle(fontSize: 14, color: AppTheme.textSecondary)),
                          const SizedBox(height: 20),
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _selectedGenre = 'All';
                                _selectedPriceRange = const RangeValues(0, 500);
                                _minRating = 0;
                                _selectedGenres = [];
                              });
                            },
                            child: const Text('Clear Filters'),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                    sliver: SliverGrid(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 0.62,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          return BookCard(book: processedBooks[index]);
                        },
                        childCount: processedBooks.length,
                      ),
                    ),
                  ),
              ],
            );
          },
          loading: () => const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: AppTheme.primary),
                SizedBox(height: 16),
                Text('Loading books...', style: TextStyle(color: AppTheme.textSecondary)),
              ],
            ),
          ),
          error: (err, stack) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline_rounded, size: 48, color: Colors.red.shade300),
                const SizedBox(height: 16),
                Text('Error: $err', style: const TextStyle(color: AppTheme.textSecondary), textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIconButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE5E7EB)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Icon(icon, size: 20, color: AppTheme.textPrimary),
      ),
    );
  }
}

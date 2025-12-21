import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:maxbillup/utils/translation_helper.dart';

// Professional Corporate Palette
const Color _primaryColor = Color(0xFF2196F3); // Slate 900 (Navy)
const Color _accentColor = Color(0xFF2196F3);  // Professional Blue
const Color _secondaryColor = Color(0xFF64748B); // Slate 500 (Grey)
const Color _cardBorder = Color(0xFFE2E8F0); // Slate 200
const Color _scaffoldBg = Color(0xFFF1F5F9); // Slate 100
const Color _surfaceColor = Colors.white;

class KnowledgePage extends StatefulWidget {
  final VoidCallback onBack;

  const KnowledgePage({
    super.key,
    required this.onBack,
  });

  @override
  State<KnowledgePage> createState() => _KnowledgePageState();
}

class _KnowledgePageState extends State<KnowledgePage> {
  String _selectedCategory = 'All';
  final List<String> _categories = ['All', 'General', 'Tutorial', 'FAQ', 'Tips', 'Updates'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _scaffoldBg,
      appBar: AppBar(
        title: Text(context.tr('knowledge_base'),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: _primaryColor,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
          onPressed: widget.onBack,
        ),
      ),
      body: Column(
        children: [
          // Category Filter Section
          _buildCategoryFilter(),

          // Knowledge Posts List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('knowledge')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: _accentColor));
                }

                // Error handling modified to hide technical error messages
                if (snapshot.hasError) {
                  return _buildEmptyState();
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return _buildEmptyState();
                }

                // Filter and sort locally to avoid composite index requirement
                var docs = snapshot.data!.docs;

                // Filter by category
                if (_selectedCategory != 'All') {
                  docs = docs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final category = (data['category'] ?? 'General').toString();
                    return category.toLowerCase() == _selectedCategory.toLowerCase();
                  }).toList();
                }

                // Sort by createdAt (newest first)
                docs.sort((a, b) {
                  final aData = a.data() as Map<String, dynamic>;
                  final bData = b.data() as Map<String, dynamic>;
                  final aTime = aData['createdAt'] as Timestamp?;
                  final bTime = bData['createdAt'] as Timestamp?;

                  if (aTime == null && bTime == null) return 0;
                  if (aTime == null) return 1;
                  if (bTime == null) return -1;
                  return bTime.compareTo(aTime);
                });

                if (docs.isEmpty) {
                  return _buildEmptyState();
                }

                return RefreshIndicator(
                  color: _accentColor,
                  onRefresh: () async => setState(() {}),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: docs.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final doc = docs[index];
                      final data = doc.data() as Map<String, dynamic>;

                      return _buildKnowledgeCard(
                        context,
                        title: data['title'] ?? 'Untitled',
                        content: data['content'] ?? '',
                        category: data['category'] ?? 'General',
                        createdAt: data['createdAt'] as Timestamp?,
                        updatedAt: data['updatedAt'] as Timestamp?,
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryFilter() {
    return Container(
      height: 64,
      width: double.infinity,
      decoration: BoxDecoration(
        color: _surfaceColor,
        border: Border(bottom: BorderSide(color: _cardBorder)),
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final category = _categories[index];
          final isSelected = _selectedCategory == category;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: ChoiceChip(
              label: Text(category),
              selected: isSelected,
              onSelected: (selected) => setState(() => _selectedCategory = category),
              selectedColor: _primaryColor,
              backgroundColor: _scaffoldBg,
              elevation: 0,
              pressElevation: 0,
              showCheckmark: false,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(color: isSelected ? _primaryColor : _cardBorder),
              ),
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : _primaryColor,
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildKnowledgeCard(
      BuildContext context, {
        required String title,
        required String content,
        required String category,
        Timestamp? createdAt,
        Timestamp? updatedAt,
      }) {
    final categoryColor = _getCategoryColor(category);
    final timeAgo = _getTimeAgo(createdAt ?? updatedAt);

    return Container(
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _cardBorder),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showKnowledgeDetail(context, title, content, category, createdAt, updatedAt),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: categoryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        category.toUpperCase(),
                        style: TextStyle(color: categoryColor, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                      ),
                    ),
                    Row(
                      children: [
                        Icon(Icons.schedule_rounded, size: 14, color: _secondaryColor.withOpacity(0.6)),
                        const SizedBox(width: 4),
                        Text(timeAgo, style: TextStyle(fontSize: 11, color: _secondaryColor, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _primaryColor, height: 1.3),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Text(
                  content,
                  style: TextStyle(fontSize: 13, color: _secondaryColor, height: 1.5),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      'Read Article',
                      style: TextStyle(color: _accentColor, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.arrow_forward_rounded, size: 16, color: _accentColor),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showKnowledgeDetail(
      BuildContext context,
      String title,
      String content,
      String category,
      Timestamp? createdAt,
      Timestamp? updatedAt,
      ) {
    final categoryColor = _getCategoryColor(category);
    final formattedDate = _formatDate(createdAt ?? updatedAt);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: _surfaceColor,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Drag Handle
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40, height: 4,
                decoration: BoxDecoration(color: _cardBorder, borderRadius: BorderRadius.circular(2)),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: categoryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(_getCategoryIcon(category), size: 14, color: categoryColor),
                            const SizedBox(width: 8),
                            Text(category, style: TextStyle(color: categoryColor, fontSize: 12, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: _primaryColor, height: 1.2)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(Icons.calendar_today_rounded, size: 14, color: _secondaryColor),
                        const SizedBox(width: 8),
                        Text(formattedDate, style: TextStyle(fontSize: 13, color: _secondaryColor, fontWeight: FontWeight.w500)),
                      ],
                    ),
                    const Padding(padding: EdgeInsets.symmetric(vertical: 24), child: Divider(height: 1, color: _cardBorder)),
                    Text(
                      content,
                      style: const TextStyle(fontSize: 15, color: _primaryColor, height: 1.7, letterSpacing: 0.2),
                    ),
                    const SizedBox(height: 40),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: const Text('Finished Reading', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: _surfaceColor, shape: BoxShape.circle, border: Border.all(color: _cardBorder)),
            child: Icon(Icons.lightbulb_outline_rounded, size: 48, color: _secondaryColor.withOpacity(0.4)),
          ),
          const SizedBox(height: 24),
          const Text('No knowledge posts yet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _primaryColor)),
          const SizedBox(height: 8),
          Text('Check back later for tutorials and tips.', style: TextStyle(fontSize: 13, color: _secondaryColor)),
        ],
      ),
    );
  }

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'tutorial': return _accentColor;
      case 'faq': return const Color(0xFFF59E0B); // Amber 500
      case 'tips': return const Color(0xFF10B981); // Emerald 500
      case 'updates': return const Color(0xFF8B5CF6); // Violet 500
      default: return _secondaryColor;
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'tutorial': return Icons.auto_stories_rounded;
      case 'faq': return Icons.help_center_rounded;
      case 'tips': return Icons.tips_and_updates_rounded;
      case 'updates': return Icons.new_releases_rounded;
      default: return Icons.info_rounded;
    }
  }

  String _getTimeAgo(Timestamp? timestamp) {
    if (timestamp == null) return 'Recently';
    final difference = DateTime.now().difference(timestamp.toDate());
    if (difference.inDays > 0) return '${difference.inDays}d ago';
    if (difference.inHours > 0) return '${difference.inHours}h ago';
    if (difference.inMinutes > 0) return '${difference.inMinutes}m ago';
    return 'Just now';
  }

  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return '';
    return DateFormat('MMMM dd, yyyy • hh:mm a').format(timestamp.toDate());
  }
}
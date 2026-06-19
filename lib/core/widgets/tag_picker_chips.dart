import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../features/transactions/domain/models/tag_model.dart';
import '../../features/transactions/providers/tag_provider.dart';

class TagPickerChips extends ConsumerStatefulWidget {
  final List<String> selectedTagIds;
  final ValueChanged<List<String>> onChanged;

  const TagPickerChips({
    super.key,
    required this.selectedTagIds,
    required this.onChanged,
  });

  @override
  ConsumerState<TagPickerChips> createState() => _TagPickerChipsState();
}

class _TagPickerChipsState extends ConsumerState<TagPickerChips> {
  bool _isCreatingNew = false;
  final _newTagController = TextEditingController();

  @override
  void dispose() {
    _newTagController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final tagsAsync = ref.watch(tagsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'transaction.tags'.tr(),
            style: TextStyle(
              color: colorScheme.onSurface,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        tagsAsync.when(
          data: (tags) => _buildChips(tags, colorScheme),
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: CircularProgressIndicator(),
            ),
          ),
          error: (error, stackTrace) => Text(
            'transaction.tags_error'.tr(),
            style: TextStyle(color: colorScheme.error),
          ),
        ),
      ],
    );
  }

  Widget _buildChips(List<Tag> tags, ColorScheme colorScheme) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        // Existing tags
        ...tags.map((tag) => _buildTagChip(tag, colorScheme)),

        // Create new tag chip
        if (_isCreatingNew)
          _buildCreateNewChip(colorScheme)
        else
          ActionChip(
            avatar: Icon(Icons.add, size: 16, color: colorScheme.primary),
            label: Text('transaction.add_tag'.tr()),
            onPressed: () {
              setState(() {
                _isCreatingNew = true;
              });
            },
            backgroundColor: colorScheme.surface,
            side: BorderSide(color: colorScheme.primary.withValues(alpha: 0.3)),
          ),
      ],
    );
  }

  Widget _buildTagChip(Tag tag, ColorScheme colorScheme) {
    final isSelected = widget.selectedTagIds.contains(tag.id);
    final tagColor = tag.color != null
        ? Color(int.parse(tag.color!.replaceFirst('#', '0xFF')))
        : colorScheme.primary;

    return FilterChip(
      label: Text(tag.name),
      selected: isSelected,
      onSelected: (selected) {
        final newSelection = List<String>.from(widget.selectedTagIds);
        if (selected) {
          newSelection.add(tag.id);
        } else {
          newSelection.remove(tag.id);
        }
        widget.onChanged(newSelection);
      },
      selectedColor: tagColor.withValues(alpha: 0.2),
      checkmarkColor: tagColor,
      side: BorderSide(
        color: isSelected
            ? tagColor.withValues(alpha: 0.5)
            : colorScheme.onSurface.withValues(alpha: 0.2),
      ),
    );
  }

  Widget _buildCreateNewChip(ColorScheme colorScheme) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 200),
      child: InputChip(
        avatar: Icon(Icons.edit, size: 16, color: colorScheme.primary),
        label: SizedBox(
          width: 120,
          child: TextField(
            controller: _newTagController,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'transaction.tag_name'.tr(),
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
            style: const TextStyle(fontSize: 14),
            onSubmitted: _createTag,
          ),
        ),
        onDeleted: () {
          setState(() {
            _isCreatingNew = false;
            _newTagController.clear();
          });
        },
        deleteIcon: const Icon(Icons.check, size: 18),
        onPressed: () => _createTag(_newTagController.text),
        backgroundColor: colorScheme.surface,
        side: BorderSide(color: colorScheme.primary.withValues(alpha: 0.3)),
      ),
    );
  }

  Future<void> _createTag(String name) async {
    if (name.trim().isEmpty) return;

    final tagNotifier = ref.read(tagNotifierProvider.notifier);
    await tagNotifier.createTag(name: name.trim());

    setState(() {
      _isCreatingNew = false;
      _newTagController.clear();
    });
  }
}

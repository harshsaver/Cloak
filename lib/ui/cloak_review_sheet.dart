import 'package:flutter/material.dart';

import '../services/cloak_review.dart';
import 'widgets.dart';

class CloakReviewSheet extends StatefulWidget {
  final CloakReview review;
  final bool usesSearch;
  final void Function(CloakReview review) onSend;
  const CloakReviewSheet({super.key, required this.review, required this.usesSearch, required this.onSend});

  @override
  State<CloakReviewSheet> createState() => _CloakReviewSheetState();
}

class _CloakReviewSheetState extends State<CloakReviewSheet> {
  late final CloakReview _review = widget.review;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final candidates = _review.available;
    final outgoing = _review.outgoing.where((m) => m.role != 'system').toList();

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620, maxHeight: 680),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Icon(Icons.visibility_rounded),
                const SizedBox(width: 8),
                const Text('Review Cloak', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ]),
              const SizedBox(height: 6),
              Text(
                'This is the exact text that will be sent${widget.usesSearch ? ', including the web search query' : ''}. '
                'Hide anything else that should not leave this device. Suggestions are found locally and may be incomplete.',
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: ListView(
                  children: [
                    Text('Outgoing', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: scheme.onSurfaceVariant)),
                    const SizedBox(height: 6),
                    for (final message in outgoing)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: PanelCard(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(message.role.toUpperCase(),
                                  style: TextStyle(
                                      fontSize: 10, fontWeight: FontWeight.w700, color: scheme.onSurfaceVariant)),
                              const SizedBox(height: 4),
                              SelectableText(message.content, style: const TextStyle(fontSize: 13, height: 1.3)),
                            ],
                          ),
                        ),
                      ),
                    if (candidates.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text('Found on this device',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: scheme.onSurfaceVariant)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final candidate in candidates)
                            FilterChip(
                              label: Text('${candidate.text}  ·  ${candidate.kind.toLowerCase()}'),
                              selected: _review.isHidden(candidate),
                              onSelected: (_) => setState(() => _review.toggle(candidate)),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    icon: const Icon(Icons.send_rounded, size: 16),
                    label: const Text('Send'),
                    onPressed: () {
                      Navigator.of(context).pop();
                      widget.onSend(_review);
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import 'package:provider/provider.dart';

import '../models/provider.dart';
import '../state/app_state.dart';
import '../state/chat_view_model.dart';
import 'settings_sheet.dart';
import 'theme.dart';
import 'widgets.dart';

/// The compact "Model ▾" button shown in the conversation header.
class ModelPickerButton extends StatelessWidget {
  final ChatViewModel vm;
  final ValueChanged<AiProvider>? onProviderChange;
  const ModelPickerButton({super.key, required this.vm, this.onProviderChange});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: vm,
      builder: (context, _) {
        return InkWell(
          borderRadius: BorderRadius.circular(7),
          onTap: vm.isStreaming ? null : () => showModelPicker(context, vm, onProviderChange: onProviderChange),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
            decoration: BoxDecoration(
              color: scheme.onSurface.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(7),
              border: Border.all(color: scheme.onSurface.withValues(alpha: 0.1)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Model', style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    vm.selectedModel.isEmpty ? 'Choose a model' : vm.selectedModel,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: CloakColors.accent),
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.expand_more_rounded, size: 14, color: CloakColors.accent),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Opens the model picker: a tall bottom sheet on phones, a dialog on desktop.
Future<void> showModelPicker(BuildContext context, ChatViewModel vm, {ValueChanged<AiProvider>? onProviderChange}) {
  if (isCompact(context)) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (sheet) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(sheet).bottom),
        child: SizedBox(
          height: MediaQuery.sizeOf(sheet).height * 0.78,
          child: _ModelPickerDialog(vm: vm, sheet: true, onProviderChange: onProviderChange),
        ),
      ),
    );
  }
  return showDialog(context: context, builder: (_) => _ModelPickerDialog(vm: vm, onProviderChange: onProviderChange));
}

class _ModelPickerDialog extends StatefulWidget {
  final ChatViewModel vm;
  final bool sheet;
  final ValueChanged<AiProvider>? onProviderChange;
  const _ModelPickerDialog({required this.vm, this.sheet = false, this.onProviderChange});

  @override
  State<_ModelPickerDialog> createState() => _ModelPickerDialogState();
}

class _ModelPickerDialogState extends State<_ModelPickerDialog> {
  final _search = TextEditingController();
  late final TextEditingController _custom = TextEditingController(text: widget.vm.selectedModel);

  @override
  void dispose() {
    _search.dispose();
    _custom.dispose();
    super.dispose();
  }

  void _useCustom() {
    final id = _custom.text.trim();
    if (id.isEmpty) return;
    widget.vm.selectModel(id);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final vm = widget.vm;
    final app = context.watch<AppState>();
    return AnimatedBuilder(
      animation: vm,
      builder: (context, _) {
        final query = _search.text.trim().toLowerCase();
        final filtered = vm.models.where((m) => query.isEmpty || m.toLowerCase().contains(query)).toList();
        final body = Padding(
              padding: widget.sheet ? const EdgeInsets.fromLTRB(16, 0, 16, 12) : const EdgeInsets.all(18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(widget.onProviderChange != null ? 'Provider & model' : 'Models',
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                      const Spacer(),
                      if (vm.isLoadingModels)
                        const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                      TextButton.icon(
                        onPressed: vm.isLoadingModels ? null : () => vm.loadModels(),
                        icon: const Icon(Icons.refresh_rounded, size: 16),
                        label: const Text('Refresh'),
                      ),
                    ],
                  ),
                  if (widget.onProviderChange != null) ...[
                    const SizedBox(height: 4),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(children: [
                        for (final p in AiProvider.all)
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ChoiceChip(
                              avatar: ProviderGlyph(provider: p, size: 20),
                              label: Text(app.hasKey(p) ? p.name : '${p.name} · Add key'),
                              selected: p == vm.provider,
                              onSelected: (_) {
                                if (p == vm.provider) return;
                                Navigator.of(context).pop();
                                // Never strand a chat on a provider it can't talk to.
                                if (!app.hasKey(p)) {
                                  showSettingsSheet(context);
                                } else {
                                  widget.onProviderChange!(p);
                                }
                              },
                            ),
                          ),
                      ]),
                    ),
                  ],
                  const SizedBox(height: 8),
                  TextField(
                    controller: _search,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      isDense: true,
                      hintText: 'Search models',
                      prefixIcon: Icon(Icons.search_rounded, size: 18),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  if (vm.modelsError != null) ...[
                    const SizedBox(height: 8),
                    Text(vm.modelsError!, style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12)),
                  ],
                  const SizedBox(height: 8),
                  Expanded(
                    child: filtered.isEmpty
                        ? Center(
                            child: Text(
                              query.isEmpty ? 'No models loaded' : 'No matching models',
                              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                            ),
                          )
                        : ListView.builder(
                            itemCount: filtered.length,
                            itemBuilder: (context, i) {
                              final model = filtered[i];
                              final selected = model == vm.selectedModel;
                              return ListTile(
                                dense: !widget.sheet,
                                title: Text(model, maxLines: 2, overflow: TextOverflow.ellipsis),
                                trailing: selected ? const Icon(Icons.check_rounded, size: 18) : null,
                                onTap: () {
                                  vm.selectModel(model);
                                  Navigator.of(context).pop();
                                },
                              );
                            },
                          ),
                  ),
                  const Divider(),
                  const Text('Enter a model ID', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _custom,
                          onSubmitted: (_) => _useCustom(),
                          decoration: const InputDecoration(
                            isDense: true,
                            hintText: 'Model ID from your provider',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(onPressed: _useCustom, child: const Text('Use')),
                    ],
                  ),
                ],
              ),
            );
        if (widget.sheet) return body;
        return Dialog(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460, maxHeight: 560),
            child: body,
          ),
        );
      },
    );
  }
}

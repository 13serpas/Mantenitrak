import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../../shared/widgets/field_label.dart';
import '../../../domain/vehicle_catalog.dart';

/// Campo de texto con sugerencias (marca, modelo, motor). El usuario puede
/// elegir una sugerencia o escribir lo que quiera.
///
/// Usa el `RawAutocomplete` de Flutter en lugar del desplegable a mano del
/// prototipo, que se dibujaba encima de los campos siguientes y no se cerraba
/// al tocar fuera.
class CatalogField extends StatefulWidget {
  const CatalogField({
    super.key,
    required this.label,
    required this.hint,
    required this.initialValue,
    required this.options,
    required this.onChanged,
    this.validator,
    this.textCapitalization = TextCapitalization.words,
    this.inputFormatters,
    this.textInputAction = TextInputAction.next,
  });

  final String label;
  final String hint;
  final String initialValue;
  final List<String> options;
  final ValueChanged<String> onChanged;
  final String? Function(String?)? validator;
  final TextCapitalization textCapitalization;
  final List<TextInputFormatter>? inputFormatters;
  final TextInputAction textInputAction;

  @override
  State<CatalogField> createState() => _CatalogFieldState();
}

class _CatalogFieldState extends State<CatalogField> {
  late final TextEditingController _controller = TextEditingController(text: widget.initialValue);
  final _focus = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FieldLabel(widget.label),
        LayoutBuilder(
          builder: (context, constraints) => RawAutocomplete<String>(
            textEditingController: _controller,
            focusNode: _focus,
            optionsBuilder: (value) => VehicleCatalog.filter(widget.options, value.text),
            onSelected: (v) {
              widget.onChanged(v);
              FocusScope.of(context).nextFocus();
            },
            fieldViewBuilder: (context, controller, focusNode, onSubmitted) => TextFormField(
              controller: controller,
              focusNode: focusNode,
              onChanged: widget.onChanged,
              validator: widget.validator,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              textCapitalization: widget.textCapitalization,
              inputFormatters: widget.inputFormatters,
              textInputAction: widget.textInputAction,
              onFieldSubmitted: (_) => onSubmitted(),
              decoration: InputDecoration(
                hintText: widget.hint,
                suffixIcon: widget.options.isEmpty ? null : const Icon(Icons.expand_more),
              ),
            ),
            optionsViewBuilder: (context, onSelected, options) => Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 6,
                borderRadius: BorderRadius.circular(12),
                clipBehavior: Clip.antiAlias,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: 240, maxWidth: constraints.maxWidth),
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    itemCount: options.length,
                    itemBuilder: (_, i) {
                      final o = options.elementAt(i);
                      return ListTile(dense: true, title: Text(o), onTap: () => onSelected(o));
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

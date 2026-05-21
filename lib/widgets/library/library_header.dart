import 'package:flutter/material.dart';

class MLibraryHeader extends StatelessWidget {
  const MLibraryHeader({
    super.key,
    required this.title,
    required this.actions,
  });

  final List<Widget>? actions;
  final String title;

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      titleSpacing: 22,
      scrolledUnderElevation: 0,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      title: Text(
        title,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onPrimaryContainer,
          fontWeight: FontWeight.w500,
        ),
      ),
      pinned: true,
      actions: actions,
    );
  }
}

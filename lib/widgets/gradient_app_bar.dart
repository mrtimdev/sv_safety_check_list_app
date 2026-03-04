import 'package:flutter/material.dart';

class GradientAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final bool? centerTitle;
  final List<Widget>? actions;
  final Widget? leading;
  final bool showLoading;

  static const Color primaryBlue = Color(0xFF1E40AF);
  static const Color secondaryBlue = Color(0xFF3B82F6);
  static const Color accentBlue = Color(0xFF60A5FA);
  static const Color lightBlue = Color(0xFFDBEAFE);
  static const Color darkBlue = Color(0xFF1E3A8A);
  static const Color surfaceBlue = Color(0xFFF0F9FF);

  const GradientAppBar({
    Key? key,
    required this.title,
    this.centerTitle = true,
    this.actions,
    this.leading,
    this.showLoading = false,
  }) : super(key: key);

  @override
  Size get preferredSize => const Size.fromHeight(70);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 20,
          letterSpacing: 0.5,
        ),
      ),
      elevation: 0,
      backgroundColor: Colors.transparent,
      foregroundColor: Colors.white,
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              primaryBlue,
              primaryBlue,
            ],
          ),
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(25),
            bottomRight: Radius.circular(25),
          ),
          boxShadow: [
            BoxShadow(
              color: Color(0xFF1E3A8A),
              offset: Offset(0, 4),
              blurRadius: 10,
              spreadRadius: 0,
            ),
          ],
        ),
      ),
      toolbarHeight: 70,
      centerTitle: centerTitle,
      leading: leading ??
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new),
            onPressed: () => Navigator.pop(context),
            color: Colors.white,
          ),
      actions: [
        if (showLoading)
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
          ),
        if (actions != null) ...actions!,
      ],
    );
  }
}

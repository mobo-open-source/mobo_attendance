import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:provider/provider.dart';
import '../../../CommonWidgets/core/language/translate_widget.dart';
import '../../../CommonWidgets/core/providers/language_provider.dart';
import '../../../CommonWidgets/core/providers/motion_provider.dart';
import '../../credetials/pages/credential_page.dart';
import '../bloc/login_bloc.dart';

/// Entry screen for login flow.
///
/// Provides LoginBloc and loads login UI.
class LoginScreen extends StatelessWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BlocProvider(create: (_) => LoginBloc(), child: const _LoginView());
  }
}

/// Main login UI container.
///
/// Handles:
/// - URL input
/// - Database selection
/// - Manual database input
/// - Next button navigation
class _LoginView extends StatefulWidget {
  const _LoginView();

  @override
  State<_LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<_LoginView> {
  final TextEditingController _manualDbController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _manualDbController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _manualDbController.dispose();
    super.dispose();
  }

  /// Builds manual database input field when server has no database list.
  Widget _buildManualDbInput() {
    return TextFormField(
      controller: _manualDbController,
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Database name is required';
        }
        return null;
      },
      decoration: InputDecoration(
        hintText: 'Enter Database Name',
        hintStyle: GoogleFonts.manrope(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: Colors.black.withOpacity(.4),
        ),
        prefixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(width: 6),
            Icon(
              HugeIcons.strokeRoundedDatabase,
              size: 18,
              color: Colors.black54,
            ),
            SizedBox(width: 12),
          ],
        ),
        prefixIconConstraints: const BoxConstraints(
          minWidth: 14,
          minHeight: 20,
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[950] : Colors.grey[50],
                image: DecorationImage(
                  image: AssetImage("assets/background.png"),
                  fit: BoxFit.cover,
                  colorFilter: ColorFilter.mode(
                    isDark
                        ? Colors.black.withOpacity(1)
                        : Colors.white.withOpacity(1),
                    BlendMode.dstATop,
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(top: 40),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    'assets/attendance-icon.png',
                    height: 30,
                    width: 30,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.delivery_dining,
                      color: Color(0xFFC03355),
                      size: 30,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'mobo attendance',
                    style: TextStyle(
                      fontFamily: 'Yaro',
                      fontSize: 24,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    children: [
                      SizedBox(height: 30),
                      tr(
                        'Sign In',
                        style: GoogleFonts.montserrat(
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          fontSize: 32,
                        ),
                      ),
                      const SizedBox(height: 6),
                      tr(
                        'use proper information to continue',
                        style: GoogleFonts.manrope(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 40),

                      const _UrlInputField(),
                      const SizedBox(height: 16),

                      BlocBuilder<LoginBloc, LoginState>(
                        builder: (context, state) {
                          if (state.showManualDbInput) {
                            return _buildManualDbInput();
                          } else if (!state.showManualDbInput &&
                              state.databases.isNotEmpty) {
                            return const _DatabaseDropdown();
                          } else {
                            return const SizedBox.shrink();
                          }
                        },
                      ),
                      const _ErrorMessage(),
                      const SizedBox(height: 24),

                      BlocSelector<LoginBloc, LoginState, bool>(
                        selector: (state) =>
                        (state.databases.isEmpty && !state.showManualDbInput) ||
                            (state.showManualDbInput &&
                                _manualDbController.text.trim().isEmpty) ||
                            (!state.showManualDbInput && state.selectedDatabase == null),
                        builder: (context, isDisabled) {
                          return SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              onPressed: isDisabled ? null : () => _onNextPressed(context),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.black,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: tr(
                                'Next',
                                style: GoogleFonts.manrope(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Handles Next button click.
  ///
  /// Navigates to CredentialsPage with:
  /// - Selected protocol
  /// - Server URL
  /// - Selected or manually entered database
  void _onNextPressed(BuildContext context) {
    final motionProvider = Provider.of<MotionProvider>(context, listen: false);

    final state = context.read<LoginBloc>().state;
    String finalDb = state.selectedDatabase ?? '';

    if (state.showManualDbInput) {
      finalDb = _manualDbController.text.trim();
    }

    String cleanUrl = state.url.trim();
    String protocolToUse = state.protocol;
    if (state.urlHistory.containsKey(cleanUrl)) {
      final entry = state.urlHistory[cleanUrl]!;

      if (state.selectedDatabase == null || state.selectedDatabase!.isEmpty) {
        finalDb = entry['db'] ?? "";
      }
    }
    if (cleanUrl.startsWith('http://')) {
      protocolToUse = 'http://';
      cleanUrl = cleanUrl.replaceFirst('http://', '');
    } else if (cleanUrl.startsWith('https://')) {
      protocolToUse = 'https://';
      cleanUrl = cleanUrl.replaceFirst('https://', '');
    }
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            CredentialsPage(
              protocol: protocolToUse,
              url: cleanUrl,
              database: finalDb,
            ),
        transitionDuration: motionProvider.reduceMotion
            ? Duration.zero
            : const Duration(milliseconds: 300),
        reverseTransitionDuration: motionProvider.reduceMotion
            ? Duration.zero
            : const Duration(milliseconds: 300),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          if (motionProvider.reduceMotion) return child;
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }
}

/// URL input field with:
/// - Protocol selector
/// - URL suggestions (autocomplete)
/// - Loading indicator while fetching databases
class _UrlInputField extends StatelessWidget {
  const _UrlInputField();

  @override
  Widget build(BuildContext context) {
    final translationService = context.read<LanguageProvider>();

    return BlocBuilder<LoginBloc, LoginState>(
      buildWhen: (p, c) =>
          p.protocol != c.protocol ||
          p.url != c.url ||
          p.isLoading != c.isLoading ||
          p.urlSuggestions != c.urlSuggestions ||
          p.urlHistory != c.urlHistory,
      builder: (context, state) {
        return RawAutocomplete<String>(
          optionsBuilder: (value) {
            final input = value.text.trim().toLowerCase();
            if (input.isEmpty) return const Iterable<String>.empty();
            final matches = state.urlSuggestions.where(
              (u) => u.toLowerCase().contains(input),
            );
            if (matches.length == 1 && matches.first.toLowerCase() == input) {
              return const Iterable<String>.empty();
            }
            return matches;
          },

          onSelected: (selection) {
            context.read<LoginBloc>().add(UrlChanged(selection));
            final entry = state.urlHistory[selection];
            if (entry != null && entry['db']?.isNotEmpty == true) {
              context.read<LoginBloc>().add(DatabaseSelected(entry['db']!));
            }
          },
          fieldViewBuilder: (context, ctrl, focusNode, onSubmitted) {
            return TextFormField(
              controller: ctrl,
              focusNode: focusNode,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return translationService.getCached(
                    'Server address is required',
                  );
                }
                return null;
              },
              onChanged: (v) => context.read<LoginBloc>().add(UrlChanged(v)),
              style: GoogleFonts.manrope(
                color: Colors.black,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                hintText:
                    translationService.getCached("Enter Server Address") ??
                    "Enter Server Address",
                hintStyle: GoogleFonts.manrope(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: Colors.black.withOpacity(.4),
                ),
                prefixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(width: 10),

                    const Icon(
                      HugeIcons.strokeRoundedServerStack01,
                      size: 20,
                      color: Colors.black54,
                    ),

                    const SizedBox(width: 10),

                    DropdownButtonHideUnderline(
                      child: DropdownButton2<String>(
                        value: state.protocol,
                        items: ['http://', 'https://']
                            .map(
                              (p) => DropdownMenuItem(
                                value: p,
                                child: Text(
                                  p,
                                  style: GoogleFonts.manrope(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.black,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (v) =>
                            context.read<LoginBloc>().add(ProtocolChanged(v!)),

                        buttonStyleData: const ButtonStyleData(
                          padding: EdgeInsets.zero,
                          height: 36,
                        ),
                        menuItemStyleData: const MenuItemStyleData(
                          padding: EdgeInsets.symmetric(horizontal: 4),
                        ),

                        iconStyleData: const IconStyleData(
                          icon: SizedBox.shrink(),
                        ),
                      ),
                    ),

                    const Icon(
                      Icons.keyboard_arrow_down,
                      size: 16,
                      color: Colors.black54,
                    ),

                    SizedBox(width: 5),
                    const SizedBox(
                      height: 39,
                      child: VerticalDivider(
                        width: 1,
                        thickness: 1,
                        color: Colors.black12,
                      ),
                    ),
                    SizedBox(width: 5),
                  ],
                ),
                suffixIcon: state.isLoading
                    ? Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.black54,
                            ),
                          ),
                        ),
                      )
                    : null,
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            );
          },
          optionsViewBuilder: (context, onSelected, options) {
            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  margin: const EdgeInsets.only(top: 5),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    itemCount: options.length,
                    itemBuilder: (context, index) {
                      final option = options.elementAt(index);
                      return InkWell(
                        onTap: () {
                          onSelected(option);
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Text(
                            option,
                            style: GoogleFonts.manrope(
                              fontSize: 14,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

/// Dropdown to select database from fetched list.
class _DatabaseDropdown extends StatelessWidget {
  const _DatabaseDropdown();

  @override
  Widget build(BuildContext context) {
    final translationService = context.read<LanguageProvider>();

    return BlocBuilder<LoginBloc, LoginState>(
      buildWhen: (p, c) =>
          p.databases != c.databases ||
          p.selectedDatabase != c.selectedDatabase,
      builder: (context, state) {
        if (state.databases.isEmpty) return const SizedBox.shrink();

        return DropdownButtonHideUnderline(
          child: DropdownButtonFormField2<String>(
            value: state.databases.contains(state.selectedDatabase)
                ? state.selectedDatabase
                : null,
            isExpanded: true,
            hint: Align(
              alignment: Alignment.centerLeft,
              child: tr(
                "Select Database",
                style: GoogleFonts.manrope(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: Colors.black.withOpacity(.4),
                ),
              ),
            ),
            items: state.databases
                .map(
                  (db) => DropdownMenuItem(
                    value: db,
                    child: Text(
                      db,
                      style: GoogleFonts.manrope(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: Colors.black,
                      ),
                    ),
                  ),
                )
                .toList(),
            onChanged: (v) =>
                context.read<LoginBloc>().add(DatabaseSelected(v!)),
            decoration: InputDecoration(
              prefixIcon: Padding(
                padding: const EdgeInsets.only(left: 2),
                child: Transform.translate(
                  offset: const Offset(7, 0),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        HugeIcons.strokeRoundedDatabase,
                        size: 20,
                        color: Colors.black54,
                      ),
                      SizedBox(width: 0),
                    ],
                  ),
                ),
              ),
              prefixIconConstraints: const BoxConstraints(
                minWidth: 0,
                minHeight: 0,
                maxWidth: 30,
              ),
              contentPadding: const EdgeInsets.fromLTRB(-4, 14, 14, 14),
              isDense: true,
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return translationService.getCached('Please select a database');
              }
              return null;
            },
            dropdownStyleData: DropdownStyleData(
              maxHeight: 200,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: Colors.white,
              ),
              offset: const Offset(0, -4),
            ),
            iconStyleData: const IconStyleData(
              icon: Icon(
                Icons.keyboard_arrow_down_rounded,
                color: Colors.black54,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Displays login related error messages.
class _ErrorMessage extends StatelessWidget {
  const _ErrorMessage();

  @override
  Widget build(BuildContext context) {
    return BlocSelector<LoginBloc, LoginState, String?>(
      selector: (state) => state.errorMessage,
      builder: (context, error) {
        if (error == null || error.isEmpty) {
          return const SizedBox.shrink();
        }

        return Padding(
          padding: const EdgeInsets.only(top: 12),
          child: tr(error, style: GoogleFonts.manrope(color: Colors.white)),
        );
      },
    );
  }
}

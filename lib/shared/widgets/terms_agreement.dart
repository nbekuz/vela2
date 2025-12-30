import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/gestures.dart';
import '../../styles/pages/login_page_styles.dart';

class TermsAgreement extends StatelessWidget {
  final Color? textColor;
  final double? fontSize;
  final double? letterSpacing;
  final double? height;

  const TermsAgreement({
    super.key,
    this.textColor,
    this.fontSize,
    this.letterSpacing,
    this.height,
  });

  Future<void> _launchUrl(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final baseStyle = LoginPageStyles.signUpTextStyle.copyWith(
      color: textColor ?? const Color(0xFFDCE6F0),
      fontSize: fontSize ?? 14,
      letterSpacing: letterSpacing ?? -0.5,
      height: height ?? 1,
    );

    final linkStyle = baseStyle.copyWith(
      decoration: TextDecoration.underline,
      height: height ?? 21 / 12,
    );

    return Container(
      padding: const EdgeInsets.only(top: 20), // Add space at top
      child: RichText(
        textAlign: TextAlign.center,
        text: TextSpan(
          style: baseStyle,
          children: [
            const TextSpan(text: 'By using Vela you agree to our '),
            TextSpan(
              text: 'Terms',
              style: linkStyle,
              recognizer: TapGestureRecognizer()
                ..onTap = () => _launchUrl('https://myvela.ai/terms-of-use/'),
            ),
            const TextSpan(text: ' and '),
            TextSpan(
              text: 'Privacy Policy',
              style: linkStyle,
              recognizer: TapGestureRecognizer()
                ..onTap = () => _launchUrl('https://privacy-g3my.vercel.app/'),
            ),
          ],
        ),
      ),
    );
  }
}

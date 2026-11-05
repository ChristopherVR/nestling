import 'package:flutter/material.dart';

import 'common.dart';
import 'theme.dart';

void showDisclaimer(BuildContext context) =>
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => const DisclaimerPage()));

class DisclaimerPage extends StatelessWidget {
  const DisclaimerPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const LText('Disclaimer & responsibility')),
    body: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        Space.page,
        Space.sm,
        Space.page,
        Space.xxl,
      ),
      child: PageWidth(
        maxWidth: 720,
        child: DefaultTextStyle.merge(
          style: Theme.of(context).textTheme.bodyLarge,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                header: true,
                child: LText(
                  'Use at your own risk',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              const SizedBox(height: Space.md),
              const LText(
                'Nestling, its code, research, documentation, integrations and all features are provided “as is” and “as available.” To the maximum extent permitted by law, the authors, contributors and distributors make no express or implied warranties, including accuracy, availability, reliability, fitness for purpose, merchantability or non-infringement.',
              ),
              const SizedBox(height: Space.lg),
              const LText(
                'To the maximum extent permitted by law, the authors, contributors and distributors accept no responsibility or liability for any person’s use, misuse, modification of, reliance on, or inability to use the software or any feature, or any resulting loss, injury, damage, costs or claims, whether direct, indirect, incidental, consequential or otherwise, under contract, negligence or any other legal theory, even if advised of the possibility.',
              ),
              const SizedBox(height: Space.lg),
              const LText(
                'This applies to every feature, including logs, reminders, syncing, camera video and audio, sound and cry alerts, room readings, device controls and experimental functions. Features may fail, be delayed, be inaccurate or be unavailable. Nestling is not a medical device, emergency service or substitute for adult supervision, professional care or independently checking a child. No feature guarantees detection or prevention of harm.',
              ),
              const SizedBox(height: Space.lg),
              const LText(
                'You remain responsible for your decisions, supervision, backups, device and network security, and using only equipment and accounts you own or are authorized to use. Third-party integrations are unofficial and are not endorsed by the device vendors.',
              ),
              const SizedBox(height: Space.lg),
              const LText(
                'Nothing here excludes, restricts or modifies rights, guarantees, remedies or liabilities that cannot lawfully be excluded, restricted or modified, including applicable rights under Australian Consumer Law. Third-party software licences continue to apply.',
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

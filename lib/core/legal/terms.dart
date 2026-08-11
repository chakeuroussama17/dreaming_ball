/// Terms of Use & Acceptable-Use rules shown (and required) at registration.
///
/// IMPORTANT: This is a good-faith template written to cover common risks — it
/// is NOT legal advice. Have a qualified lawyer in your jurisdiction review and
/// adjust the wording (and the governing-law clause) before relying on it.
///
/// Bump [kTermsVersion] whenever you change the wording. Each user's accepted
/// version + timestamp is recorded on their profile (users.terms_version /
/// users.terms_accepted_at), so you can prove exactly what they agreed to and
/// when.
library;

const String kTermsVersion = '1.0';
const String kTermsEffectiveDate = 'June 2026';

class TermsSection {
  final String title;
  final String body;
  const TermsSection(this.title, this.body);
}

const String kTermsIntro =
    'Welcome to Boundless. Before creating your account, please read and '
    'accept these Terms of Use and Acceptable-Use Rules. By tapping "I Agree", '
    'you confirm that you have read, understood, and agree to be bound by them.';

const List<TermsSection> kTermsSections = [
  TermsSection(
    '1. Purpose & eligibility',
    'Boundless is a platform for organising and joining recreational '
        'football games and tournaments. You confirm that you are of legal age '
        'in your country (or have a parent/guardian\'s consent) and that all '
        'the information you provide is true and accurate.',
  ),
  TermsSection(
    '2. Lawful use only',
    'You will use the app strictly for its intended sporting and social '
        'purposes and in full compliance with all applicable laws. You will not '
        'use it for any illegal, fraudulent, deceptive, or harmful activity.',
  ),
  TermsSection(
    '3. No money laundering or illicit funds',
    'You must not use the app — or any payment feature accessed through it — to '
        'launder money, finance illegal activity, evade taxes or sanctions, or '
        'disguise the source or ownership of funds. Any money exchanged must '
        'relate only to legitimate game or tournament fees. We may report '
        'suspicious activity to the relevant authorities and cooperate with any '
        'lawful investigation.',
  ),
  TermsSection(
    '4. Payments are between users',
    'Boundless only helps connect players and organisers. It is NOT a bank, '
        'money-services business, payment processor, or escrow provider, and it '
        'does not hold, transfer, or guarantee any funds. Any payment is made '
        'directly between users, at their own risk and responsibility. We are '
        'not responsible for payment disputes, refunds, or chargebacks.',
  ),
  TermsSection(
    '5. No gambling or betting',
    'You will not use the app to organise, promote, or take part in any illegal '
        'betting, wagering, or gambling on games or results.',
  ),
  TermsSection(
    '6. Fair play & conduct',
    'You will treat other users with respect. No harassment, threats, violence, '
        'discrimination, hate speech, cheating, or impersonation. Accounts that '
        'breach these rules may be suspended or removed.',
  ),
  TermsSection(
    '7. Assumption of risk',
    'Football is a physical activity. You take part in any game entirely at '
        'your own risk. To the fullest extent permitted by law, Boundless '
        'and its owner are not liable for any injury, loss, or damage arising '
        'from games, venues, travel, or interactions with other users. We do '
        'not supervise, vet, or guarantee games, venues, teams, agents, or '
        'other users.',
  ),
  TermsSection(
    '8. Your responsibility',
    'You are responsible for your own conduct, safety, and belongings, and for '
        'verifying the people and games you engage with. Any interaction with '
        'another user is solely between you and them.',
  ),
  TermsSection(
    '9. Data & privacy',
    'You consent to us collecting and processing the information you provide in '
        'order to operate the app, in line with our Privacy Policy.',
  ),
  TermsSection(
    '10. Suspension & indemnity',
    'We may suspend or terminate any account that violates these terms. You '
        'agree to indemnify and hold harmless Boundless and its owner from '
        'any claim, loss, or cost arising from your misuse of the app or your '
        'breach of these terms.',
  ),
  TermsSection(
    '11. Changes & governing law',
    'We may update these terms from time to time; continued use of the app '
        'means you accept the updated terms. These terms are governed by the '
        'laws of Malaysia, and any dispute is subject to the courts of Malaysia.',
  ),
];

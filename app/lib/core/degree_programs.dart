import 'package:campus_arena/l10n/app_localizations.dart';

// Fixed Politecnico di Milano degree-program list backing the registration
// dropdown. `degreeProgram` is immutable after registration and drives the
// course-rivalry leaderboard, so it must come from a closed set, not free text.
// Stored in English (canonical) in Firestore.
const List<String> kDegreePrograms = <String>[
  'Aerospace Engineering',
  'Architecture',
  'Biomedical Engineering',
  'Chemical Engineering',
  'Civil Engineering',
  'Computer Science and Engineering',
  'Design',
  'Electrical Engineering',
  'Electronic Engineering',
  'Energy Engineering',
  'Management Engineering',
  'Mathematical Engineering',
  'Mechanical Engineering',
  'Telecommunication Engineering',
  'Urban Planning',
];

String localizeDegreeProgram(AppLocalizations l10n, String program) {
  switch (program) {
    case 'Aerospace Engineering':
      return l10n.degAerospace;
    case 'Architecture':
      return l10n.degArchitecture;
    case 'Biomedical Engineering':
      return l10n.degBiomedical;
    case 'Chemical Engineering':
      return l10n.degChemical;
    case 'Civil Engineering':
      return l10n.degCivil;
    case 'Computer Science and Engineering':
      return l10n.degComputer;
    case 'Design':
      return l10n.degDesign;
    case 'Electrical Engineering':
      return l10n.degElectrical;
    case 'Electronic Engineering':
      return l10n.degElectronic;
    case 'Energy Engineering':
      return l10n.degEnergy;
    case 'Management Engineering':
      return l10n.degManagement;
    case 'Mathematical Engineering':
      return l10n.degMathematical;
    case 'Mechanical Engineering':
      return l10n.degMechanical;
    case 'Telecommunication Engineering':
      return l10n.degTelecom;
    case 'Urban Planning':
      return l10n.degUrban;
    default:
      return program;
  }
}

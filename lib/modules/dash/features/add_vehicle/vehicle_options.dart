/// Static catalogs backing the vehicle-onboarding pickers. Curated for the
/// Nigerian market — comprehensive enough to cover the common fleet without a
/// backend round-trip. `Model` lists are keyed by make; an unknown make (or
/// "Other") falls back to a free-text model entry in the UI.
library;

/// Transmission options — (wire value, label).
const List<(String, String)> kTransmissionOptions = <(String, String)>[
  ('auto', 'Automatic'),
  ('manual', 'Manual'),
];

/// Fuel-type options — (wire value, label).
const List<(String, String)> kFuelTypeOptions = <(String, String)>[
  ('fuel', 'Fuel (petrol)'),
  ('diesel', 'Diesel'),
  ('electric', 'Electric'),
  ('fuel_cng', 'Fuel / CNG'),
];

/// The 10 primary colours shown first; picking "Other" reveals [kMoreColours].
const List<String> kPrimaryColours = <String>[
  'White',
  'Black',
  'Silver',
  'Grey',
  'Blue',
  'Red',
  'Green',
  'Gold',
  'Brown',
  'Beige',
];

/// 20 additional colours behind the "Other" option.
const List<String> kMoreColours = <String>[
  'Ash',
  'Bronze',
  'Burgundy',
  'Champagne',
  'Charcoal',
  'Cream',
  'Dark Blue',
  'Dark Green',
  'Ivory',
  'Maroon',
  'Navy',
  'Orange',
  'Pearl',
  'Pink',
  'Purple',
  'Sky Blue',
  'Teal',
  'Turquoise',
  'Wine',
  'Yellow',
];

/// Earliest selectable model year (per the brief: 2004 → current year).
const int kMinVehicleYear = 2004;

/// Makes → their common models. Alphabetical; "Other" lets a driver type a
/// make/model we haven't listed.
const Map<String, List<String>> kVehicleMakes = <String, List<String>>{
  'Acura': <String>['ILX', 'MDX', 'RDX', 'TLX', 'TSX', 'ZDX'],
  'Audi': <String>['A3', 'A4', 'A6', 'A8', 'Q3', 'Q5', 'Q7', 'Q8'],
  'BMW': <String>['1 Series', '3 Series', '5 Series', '7 Series', 'X1', 'X3', 'X5', 'X6'],
  'Chevrolet': <String>['Aveo', 'Cruze', 'Malibu', 'Spark', 'Trailblazer'],
  'Chery': <String>['Tiggo 2', 'Tiggo 4', 'Tiggo 7', 'Tiggo 8'],
  'Dodge': <String>['Charger', 'Durango', 'Journey'],
  'Ford': <String>['Ecosport', 'Edge', 'Escape', 'Explorer', 'Focus', 'Fusion', 'Ranger'],
  'Honda': <String>['Accord', 'City', 'Civic', 'CR-V', 'HR-V', 'Odyssey', 'Pilot'],
  'Hyundai': <String>['Accent', 'Creta', 'Elantra', 'Santa Fe', 'Sonata', 'Tucson'],
  'Infiniti': <String>['FX35', 'JX35', 'Q50', 'QX56', 'QX60', 'QX80'],
  'Jeep': <String>['Cherokee', 'Compass', 'Grand Cherokee', 'Wrangler'],
  'Kia': <String>['Cerato', 'Optima', 'Picanto', 'Rio', 'Sorento', 'Sportage'],
  'Land Rover': <String>['Discovery', 'Range Rover', 'Range Rover Sport'],
  'Lexus': <String>['ES', 'GX', 'IS', 'LX', 'NX', 'RX'],
  'Mazda': <String>['CX-5', 'CX-7', 'CX-9', 'Mazda3', 'Mazda6'],
  'Mercedes-Benz': <String>['A-Class', 'C-Class', 'E-Class', 'GLC', 'GLE', 'GLK', 'ML', 'S-Class'],
  'Mitsubishi': <String>['ASX', 'L200', 'Outlander', 'Pajero'],
  'Nissan': <String>['Almera', 'Altima', 'Murano', 'Pathfinder', 'Rogue', 'Sentra', 'X-Trail'],
  'Peugeot': <String>['206', '301', '308', '406', '508', '3008'],
  'Suzuki': <String>['Alto', 'Ciaz', 'Swift', 'Vitara'],
  'Toyota': <String>[
    'Avensis',
    'Camry',
    'Corolla',
    'Hiace',
    'Highlander',
    'Land Cruiser',
    'Matrix',
    'Prado',
    'RAV4',
    'Sienna',
    'Venza',
    'Yaris',
  ],
  'Volkswagen': <String>['Golf', 'Jetta', 'Passat', 'Polo', 'Tiguan', 'Touareg'],
  'Volvo': <String>['S60', 'S90', 'XC40', 'XC60', 'XC90'],
  'Other': <String>[],
};

/// Makes as a display list (keys of [kVehicleMakes]).
List<String> get kVehicleMakeNames => kVehicleMakes.keys.toList(growable: false);

/// Models for [make]; empty for unknown makes / "Other" (free-text entry).
List<String> modelsForMake(String make) =>
    kVehicleMakes[make] ?? const <String>[];

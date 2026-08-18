class RailwayTrain {
  final String number;
  final String name;
  final List<String> coaches;

  const RailwayTrain({
    required this.number,
    required this.name,
    required this.coaches,
  });

  String get label => '$number — $name';
}

/// Starter railway catalog used by the prototype.
///
/// Coach composition can change operationally, so this is intentionally kept
/// as app data rather than presented as a live Indian Railways guarantee.
/// The request form only permits values from this catalog.
const List<RailwayTrain> railwayTrains = [
  RailwayTrain(
    number: '12001',
    name: 'Bhopal Shatabdi Express',
    coaches: ['C1', 'C2', 'C3', 'C4', 'C5', 'C6', 'C7', 'C8', 'C9', 'C10', 'C11', 'C12', 'E1', 'E2'],
  ),
  RailwayTrain(
    number: '12002',
    name: 'Bhopal Shatabdi Express',
    coaches: ['C1', 'C2', 'C3', 'C4', 'C5', 'C6', 'C7', 'C8', 'C9', 'C10', 'C11', 'C12', 'E1', 'E2'],
  ),
  RailwayTrain(
    number: '12625',
    name: 'Kerala Express',
    coaches: ['A1', 'A2', 'B1', 'B2', 'B3', 'B4', 'B5', 'B6', 'B7', 'B8', 'B9', 'S1', 'S2', 'S3', 'S4', 'S5', 'S6', 'S7', 'S8', 'S9', 'S10', 'S11', 'S12', 'S13', 'S14', 'GS1', 'GS2'],
  ),
  RailwayTrain(
    number: '12626',
    name: 'Kerala Express',
    coaches: ['A1', 'A2', 'B1', 'B2', 'B3', 'B4', 'B5', 'B6', 'B7', 'B8', 'B9', 'S1', 'S2', 'S3', 'S4', 'S5', 'S6', 'S7', 'S8', 'S9', 'S10', 'S11', 'S12', 'S13', 'S14', 'GS1', 'GS2'],
  ),
  RailwayTrain(
    number: '12951',
    name: 'Mumbai Rajdhani Express',
    coaches: ['1A', 'A1', 'A2', 'A3', 'B1', 'B2', 'B3', 'B4', 'B5', 'B6', 'B7', 'B8', 'B9', 'B10', 'B11', 'B12', 'B13', 'PC', 'E1', 'E2'],
  ),
  RailwayTrain(
    number: '12952',
    name: 'Mumbai Rajdhani Express',
    coaches: ['1A', 'A1', 'A2', 'A3', 'B1', 'B2', 'B3', 'B4', 'B5', 'B6', 'B7', 'B8', 'B9', 'B10', 'B11', 'B12', 'B13', 'PC', 'E1', 'E2'],
  ),
  RailwayTrain(
    number: '12645',
    name: 'Ernakulam–Hazrat Nizamuddin Millennium Express',
    coaches: ['A1', 'A2', 'B1', 'B2', 'B3', 'B4', 'B5', 'B6', 'B7', 'B8', 'S1', 'S2', 'S3', 'S4', 'S5', 'S6', 'S7', 'S8', 'S9', 'S10', 'GS1', 'GS2'],
  ),
  RailwayTrain(
    number: '12646',
    name: 'Hazrat Nizamuddin–Ernakulam Millennium Express',
    coaches: ['A1', 'A2', 'B1', 'B2', 'B3', 'B4', 'B5', 'B6', 'B7', 'B8', 'S1', 'S2', 'S3', 'S4', 'S5', 'S6', 'S7', 'S8', 'S9', 'S10', 'GS1', 'GS2'],
  ),
  RailwayTrain(
    number: '12075',
    name: 'Kozhikode–Thiruvananthapuram Jan Shatabdi Express',
    coaches: ['C1', 'C2', 'C3', 'C4', 'C5', 'C6', 'C7', 'C8', 'D1', 'D2', 'D3', 'D4', 'D5', 'D6', 'D7', 'D8', 'D9', 'D10'],
  ),
  RailwayTrain(
    number: '12076',
    name: 'Thiruvananthapuram–Kozhikode Jan Shatabdi Express',
    coaches: ['C1', 'C2', 'C3', 'C4', 'C5', 'C6', 'C7', 'C8', 'D1', 'D2', 'D3', 'D4', 'D5', 'D6', 'D7', 'D8', 'D9', 'D10'],
  ),
  RailwayTrain(
    number: '12217',
    name: 'Kerala Sampark Kranti Express',
    coaches: ['A1', 'A2', 'B1', 'B2', 'B3', 'B4', 'B5', 'B6', 'B7', 'B8', 'S1', 'S2', 'S3', 'S4', 'S5', 'S6', 'S7', 'S8', 'S9', 'S10', 'S11', 'S12', 'GS1', 'GS2'],
  ),
  RailwayTrain(
    number: '12218',
    name: 'Kerala Sampark Kranti Express',
    coaches: ['A1', 'A2', 'B1', 'B2', 'B3', 'B4', 'B5', 'B6', 'B7', 'B8', 'S1', 'S2', 'S3', 'S4', 'S5', 'S6', 'S7', 'S8', 'S9', 'S10', 'S11', 'S12', 'GS1', 'GS2'],
  ),
  RailwayTrain(
    number: '16345',
    name: 'Netravati Express',
    coaches: ['A1', 'A2', 'B1', 'B2', 'B3', 'B4', 'B5', 'B6', 'B7', 'B8', 'B9', 'S1', 'S2', 'S3', 'S4', 'S5', 'S6', 'S7', 'S8', 'S9', 'S10', 'S11', 'S12', 'S13', 'S14', 'GS1', 'GS2'],
  ),
  RailwayTrain(
    number: '16346',
    name: 'Netravati Express',
    coaches: ['A1', 'A2', 'B1', 'B2', 'B3', 'B4', 'B5', 'B6', 'B7', 'B8', 'B9', 'S1', 'S2', 'S3', 'S4', 'S5', 'S6', 'S7', 'S8', 'S9', 'S10', 'S11', 'S12', 'S13', 'S14', 'GS1', 'GS2'],
  ),
];

RailwayTrain? findTrainByNumber(String number) {
  for (final train in railwayTrains) {
    if (train.number == number) return train;
  }
  return null;
}

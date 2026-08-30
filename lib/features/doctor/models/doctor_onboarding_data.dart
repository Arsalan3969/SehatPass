import 'doctor_profile_model.dart';
import 'clinic_model.dart';
import 'clinic_service_model.dart';
import 'doctor_availability_model.dart';

class DoctorOnboardingData {
  DoctorProfileModel profile;
  ClinicModel clinic;
  List<ClinicServiceModel> services;
  DoctorAvailabilityModel availability;
  bool isPublished;

  DoctorOnboardingData({
    DoctorProfileModel? profile,
    ClinicModel? clinic,
    List<ClinicServiceModel>? services,
    DoctorAvailabilityModel? availability,
    this.isPublished = false,
  })  : profile = profile ?? DoctorProfileModel(),
        clinic = clinic ?? ClinicModel(),
        services = services ??
            [
              ClinicServiceModel(
                id: '1',
                name: 'General Consultation',
                fee: 2000,
              ),
              ClinicServiceModel(
                id: '2',
                name: 'Follow-up Consultation',
                fee: 1500,
              ),
              ClinicServiceModel(
                id: '3',
                name: 'ECG Consultation',
                fee: 2500,
              ),
            ],
        availability = availability ?? DoctorAvailabilityModel();

  void addService(String name, double fee) {
    final newId = DateTime.now().millisecondsSinceEpoch.toString();
    services.add(ClinicServiceModel(id: newId, name: name, fee: fee));
  }

  void updateService(String id, String name, double fee) {
    final index = services.indexWhere((s) => s.id == id);
    if (index != -1) {
      services[index] = ClinicServiceModel(id: id, name: name, fee: fee);
    }
  }

  void removeService(String id) {
    services.removeWhere((s) => s.id == id);
  }

  Map<String, dynamic> toMap() {
    return {
      'profile': profile.toMap(),
      'clinic': clinic.toMap(),
      'services': services.map((s) => s.toMap()).toList(),
      'availability': availability.toMap(),
      'is_published': isPublished,
    };
  }
}

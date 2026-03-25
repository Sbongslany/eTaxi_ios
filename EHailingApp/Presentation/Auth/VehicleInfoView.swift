import SwiftUI

struct VehicleInfoView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @State private var info = VehicleInfoEntity()

    var body: some View {
        NavigationStack {
            ZStack {
                Color.eBackground.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {

                        // Progress bar - step 2 of 2
                        HStack(spacing: 8) {
                            Capsule().fill(Color.eGreen).frame(height: 3)
                            Capsule().fill(Color.eGreen).frame(height: 3)
                        }
                        .padding(.bottom, 24)

                        // Back
                        EBackButton { authVM.screen = .register }
                            .padding(.bottom, 20)

                        Text("Vehicle Details")
                            .font(EFont.display(26, weight: .heavy))
                            .foregroundColor(.eText)
                            .padding(.bottom, 6)
                        Text("Tell us about the vehicle you'll be driving")
                            .font(EFont.body(15))
                            .foregroundColor(.eTextSoft)
                            .padding(.bottom, 28)

                        // Make + Model
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 8) {
                                EFieldLabel(text: "Make")
                                ETextField(placeholder: "Toyota", text: $info.make)
                            }
                            VStack(alignment: .leading, spacing: 8) {
                                EFieldLabel(text: "Model")
                                ETextField(placeholder: "Corolla", text: $info.model)
                            }
                        }
                        .padding(.bottom, 16)

                        // Year + Colour
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 8) {
                                EFieldLabel(text: "Year")
                                ETextField(placeholder: "2019", text: $info.year,
                                           keyboard: .numberPad)
                            }
                            VStack(alignment: .leading, spacing: 8) {
                                EFieldLabel(text: "Colour")
                                ETextField(placeholder: "Silver", text: $info.colour)
                            }
                        }
                        .padding(.bottom, 16)

                        // Registration
                        VStack(alignment: .leading, spacing: 8) {
                            EFieldLabel(text: "Registration Number")
                            ETextField(placeholder: "GP 76677 H",
                                       text: $info.registration)
                        }
                        .padding(.bottom, 20)

                        // Vehicle Type
                        VStack(alignment: .leading, spacing: 10) {
                            EFieldLabel(text: "Vehicle Type")
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 10) {
                                    ForEach(VehicleInfoEntity.types, id: \.self) { type in
                                        vehicleTypeChip(type)
                                    }
                                }
                            }
                        }
                        .padding(.bottom, 20)

                        // NaTIS notice
                        HStack(spacing: 10) {
                            Image(systemName: "checkmark.shield.fill")
                                .foregroundColor(.eGreen)
                            Text("Your vehicle details are verified against NaTIS. Make sure registration matches your vehicle registration document.")
                                .font(EFont.body(13))
                                .foregroundColor(.eTextSoft)
                        }
                        .padding(14)
                        .background(Color.eGreen.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: ERadius.sm))
                        .overlay(RoundedRectangle(cornerRadius: ERadius.sm)
                            .stroke(Color.eGreen.opacity(0.2), lineWidth: 1))
                        .padding(.bottom, 24)

                        // Error
                        if let err = authVM.errorMessage {
                            EErrorBanner(message: err).padding(.bottom, 16)
                        }

                        // CTA
                        EPrimaryButton(
                            title: "Create Driver Account",
                            isDisabled: !info.isValid
                        ) {
                            authVM.submitVehicleInfo(info)
                        }
                        .padding(.bottom, 40)
                    }
                    .padding(.horizontal, 24)
                }
            }
            .navigationTitle("Vehicle Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { authVM.screen = .login }
                        .foregroundColor(.eTextSoft)
                        .padding(.horizontal, 4).padding(.vertical, 6)
                        .background(Color.eSurface)
                        .clipShape(Capsule())
                }
            }
        }
    }

    @ViewBuilder
    private func vehicleTypeChip(_ type: String) -> some View {
        Button {
            withAnimation(.spring(response: 0.25)) { info.vehicleType = type }
        } label: {
            Text(type)
                .font(EFont.body(14, weight: .semibold))
                .foregroundColor(info.vehicleType == type ? .black : .eText)
                .padding(.horizontal, 18).padding(.vertical, 10)
                .background(info.vehicleType == type ? Color.eGreen : Color.eSurface)
                .clipShape(Capsule())
                .overlay(
                    Capsule().stroke(
                        info.vehicleType == type ? Color.clear : Color.eBorder,
                        lineWidth: 1.5)
                )
        }
    }
}

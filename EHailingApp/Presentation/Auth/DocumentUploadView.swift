import SwiftUI
import PhotosUI

// MARK: - Required Documents Definition
private struct DocRequirement: Identifiable {
    let id:          String   // matches backend documentType
    let label:       String
    let description: String
    let icon:        String
    let category:    String
}

private let requiredDocs: [DocRequirement] = [
    DocRequirement(id: "profile_photo",          label: "Profile Photo",          description: "Clear face photo",                       icon: "person.crop.circle.fill",  category: "Identity"),
    DocRequirement(id: "id_document",            label: "SA ID / Passport",       description: "South African ID or valid passport",      icon: "creditcard.fill",          category: "Identity"),
    DocRequirement(id: "drivers_licence",        label: "Driver's Licence",       description: "Valid SA driver's licence",               icon: "car.fill",                 category: "NRTA"),
    DocRequirement(id: "pdp",                    label: "PDP Certificate",        description: "Professional Driving Permit",             icon: "doc.badge.gearshape.fill", category: "NRTA §32"),
    DocRequirement(id: "vehicle_registration",   label: "Vehicle Registration",   description: "NaTIS vehicle registration",              icon: "doc.plaintext.fill",       category: "NaTIS"),
    DocRequirement(id: "roadworthy_certificate", label: "Roadworthy Certificate", description: "Valid certificate of roadworthiness",     icon: "checkmark.seal.fill",      category: "COR"),
    DocRequirement(id: "operating_licence",      label: "Operating Licence",      description: "NLTA operating permit",                  icon: "building.2.crop.circle",   category: "NLTA §66"),
    DocRequirement(id: "vehicle_insurance",      label: "Vehicle Insurance",      description: "Third-party insurance minimum",          icon: "shield.fill",              category: "Insurance"),
    DocRequirement(id: "police_clearance",       label: "Police Clearance",       description: "SAPS National Police Clearance",         icon: "person.badge.shield.fill", category: "SAPS NPC"),
    DocRequirement(id: "vehicle_photo",          label: "Vehicle Photo (Front)",  description: "Clear front-facing vehicle photo",       icon: "car.2.fill",               category: "Verification"),
]

// MARK: - Document Upload View
struct DocumentUploadView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @State private var selectedDocId: String?
    @State private var showPicker    = false
    @State private var pickerItem:   PhotosPickerItem?

    var uploadedCount: Int { authVM.uploadedDocTypes.count }
    var totalDocs:     Int { requiredDocs.count }

    var body: some View {
        ZStack {
            Color.eBackground.ignoresSafeArea()

            VStack(spacing: 0) {

                // Header
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Upload Documents")
                            .font(EFont.display(24, weight: .heavy))
                            .foregroundColor(.eText)
                        Text("SA law requires all \(totalDocs) documents before you can drive")
                            .font(EFont.body(13))
                            .foregroundColor(.eTextSoft)
                    }
                    Spacer()

                    // Progress ring
                    ZStack {
                        Circle()
                            .stroke(Color.eSurface, lineWidth: 4)
                            .frame(width: 64, height: 64)
                        Circle()
                            .trim(from: 0, to: authVM.uploadProgress)
                            .stroke(Color.eGreen, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                            .frame(width: 64, height: 64)
                            .rotationEffect(.degrees(-90))
                            .animation(.easeInOut, value: authVM.uploadProgress)
                        Text("\(uploadedCount)/\(totalDocs)")
                            .font(EFont.body(13, weight: .bold))
                            .foregroundColor(uploadedCount == totalDocs ? .eGreen : .eText)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 56)
                .padding(.bottom, 16)

                Divider().background(Color.eBorder).padding(.horizontal, 20)

                // Error
                if let err = authVM.uploadError {
                    EErrorBanner(message: err)
                        .padding(.horizontal, 20)
                        .padding(.top, 12)
                }

                // Document list
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 10) {
                        ForEach(requiredDocs) { doc in
                            docRow(doc)
                        }

                        // Submit notice or button
                        if authVM.allMandatoryUploaded {
                            EPrimaryButton(title: "Submit for Review") {
                                authVM.proceedFromDocuments()
                            }
                            .padding(.top, 8)
                        } else {
                            Text("Upload all \(totalDocs) documents to submit")
                                .font(EFont.body(13))
                                .foregroundColor(.eTextMuted)
                                .frame(maxWidth: .infinity)
                                .padding(.top, 12)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 40)
                }
            }
        }
        .photosPicker(
            isPresented: $showPicker,
            selection: $pickerItem,
            matching: .images)
        .onChange(of: pickerItem) { item in
            guard let docId = selectedDocId, let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    await authVM.uploadDocument(
                        type: docId,
                        data: data,
                        fileName: "\(docId)_\(Int(Date().timeIntervalSince1970)).jpg",
                        mimeType: "image/jpeg")
                }
                pickerItem = nil
            }
        }
        .task { await authVM.loadDocuments() }
    }

    @ViewBuilder
    private func docRow(_ doc: DocRequirement) -> some View {
        let isUploaded  = authVM.uploadedDocTypes.contains(doc.id)
        let isUploading = authVM.uploadingType == doc.id
        let uploaded    = authVM.uploadedDocs.first { $0.documentType == doc.id }
        let isRejected  = uploaded?.status == "rejected"

        Button {
            guard !isUploading else { return }
            selectedDocId = doc.id
            showPicker    = true
        } label: {
            HStack(spacing: 14) {

                // Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(iconBg(isUploaded: isUploaded, isRejected: isRejected))
                        .frame(width: 44, height: 44)
                    if isUploading {
                        ProgressView().tint(.eGreen).scaleEffect(0.8)
                    } else {
                        Image(systemName: doc.icon)
                            .font(.system(size: 18))
                            .foregroundColor(iconColor(isUploaded: isUploaded, isRejected: isRejected))
                    }
                }

                // Labels
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(doc.label)
                            .font(EFont.body(15, weight: .semibold))
                            .foregroundColor(.eText)
                        Text(doc.category)
                            .font(EFont.body(10, weight: .bold))
                            .foregroundColor(.eTextMuted)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Color.eSurface2)
                            .clipShape(Capsule())
                    }
                    if isRejected, let reason = uploaded?.rejectionReason {
                        Text("Rejected: \(reason)")
                            .font(EFont.body(11)).foregroundColor(.eRed)
                    } else {
                        Text(doc.description)
                            .font(EFont.body(12)).foregroundColor(.eTextMuted)
                    }
                }

                Spacer()

                // Status indicator
                if isUploaded && !isRejected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.eGreen)
                } else if isRejected {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.eRed)
                } else {
                    Image(systemName: "plus.circle")
                        .font(.system(size: 22))
                        .foregroundColor(.eGreen)
                }
            }
            .padding(16)
            .background(Color.eSurface)
            .clipShape(RoundedRectangle(cornerRadius: ERadius.md))
            .overlay(
                RoundedRectangle(cornerRadius: ERadius.md)
                    .stroke(
                        isRejected ? Color.eRed.opacity(0.4) :
                        isUploaded ? Color.eGreen.opacity(0.3) :
                        Color.eBorder,
                        lineWidth: 1.5)
            )
        }
        .disabled(isUploading)
    }

    private func iconBg(isUploaded: Bool, isRejected: Bool) -> Color {
        if isRejected { return Color.eRed.opacity(0.1) }
        if isUploaded { return Color.eGreen.opacity(0.1) }
        return Color.eSurface2
    }

    private func iconColor(isUploaded: Bool, isRejected: Bool) -> Color {
        if isRejected { return .eRed }
        if isUploaded { return .eGreen }
        return .eTextMuted
    }
}

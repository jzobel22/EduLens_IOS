import SwiftUI

struct SideMenuView: View {
    @EnvironmentObject var appState: AppState
    @Binding var selected: MainSection
    @Binding var showMenu: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text("EduLens")
                    .font(.title3.bold())
                if let name = appState.branding?.school_name {
                    Text(name)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 24)
            .padding(.bottom, 16)

            Divider()

            ForEach(MainSection.allCases) { section in
                Button {
                    withAnimation(.easeOut(duration: 0.2)) {
                        selected = section
                        showMenu = false
                    }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: section.systemImage)
                            .imageScale(.medium)
                        Text(section.label)
                            .font(.subheadline)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                }
                .foregroundColor(selected == section ? .accentColor : .primary)
            }

            Spacer()

            Button {
                withAnimation(.easeOut(duration: 0.2)) {
                    appState.reset()
                }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .imageScale(.medium)
                    Text("Sign out")
                        .font(.subheadline)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .foregroundColor(.red)

            Spacer().frame(height: 20)
        }
        .frame(maxHeight: .infinity)
        .background(
            Color(.systemBackground)
                .shadow(radius: 8)
        )
    }
}

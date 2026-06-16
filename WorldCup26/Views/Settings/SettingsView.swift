import SwiftUI

/// Profile / Settings: language, appearance, support, share, about.
struct SettingsView: View {
    @Environment(LocalizationManager.self) private var localization
    @Environment(ThemeManager.self) private var theme
    @State private var model = SettingsViewModel()

    var body: some View {
        @Bindable var localization = localization
        @Bindable var theme = theme

        Form {
            preferencesSection(localization: $localization.language, theme: $theme.appearance)
            supportSection
            shareSection
            dataSection
            aboutSection
        }
        .navigationTitle(LKey("tab.settings"))
    }

    // MARK: Support

    private var supportSection: some View {
        Section {
            Link(destination: SupportLink.url) {
                Label {
                    Text(key: "support.me")
                } icon: {
                    Image(systemName: "cup.and.saucer.fill").foregroundStyle(.orange)
                }
            }
        }
    }

    // MARK: Preferences

    private func preferencesSection(localization: Binding<AppLanguage>, theme: Binding<ThemeManager.Appearance>) -> some View {
        Section {
            Picker(selection: localization) {
                ForEach(AppLanguage.allCases) { language in
                    Text(verbatim: "\(language.flag)  \(language.nativeName)").tag(language)
                }
            } label: {
                Label(LKey("settings.language"), systemImage: "globe")
            }
            .pickerStyle(.navigationLink)

            Picker(selection: theme) {
                ForEach(ThemeManager.Appearance.allCases) { appearance in
                    Text(key: appearance.titleKey).tag(appearance)
                }
            } label: {
                Label(LKey("settings.theme"), systemImage: "circle.lefthalf.filled")
            }
        }
    }

    // MARK: Share

    private var shareSection: some View {
        Section {
            ShareLink(item: model.shareURL, message: Text(verbatim: model.shareMessage)) {
                Label(LKey("settings.share"), systemImage: "square.and.arrow.up")
            }

            Link(destination: model.reviewURL) {
                Label {
                    Text(key: "settings.rate")
                } icon: {
                    Image(systemName: "star.fill").foregroundStyle(.yellow)
                }
            }
        }
    }

    // MARK: Data

    private var dataSection: some View {
        Section {
            Text(key: "settings.data.note")
                .font(.footnote)
                .foregroundStyle(.secondary)
        } header: {
            Text(key: "settings.data")
        }
    }

    // MARK: About

    private var aboutSection: some View {
        Section {
            HStack {
                Text(key: "settings.version")
                Spacer()
                Text(verbatim: model.appVersion).foregroundStyle(.secondary)
            }
        } header: {
            Text(key: "settings.about")
        }
    }
}

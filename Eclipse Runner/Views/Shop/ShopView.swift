import SwiftUI

// MARK: - ShopView

struct ShopView: View {
    @EnvironmentObject private var store: GameStore
    @EnvironmentObject private var lang: LanguageManager
    @Environment(\.dismiss) private var dismiss

    @State private var selectedTab: ShopTab = .skins
    @State private var previewSkinID: String = ""
    @State private var showBuyConfirm: AstronautSkin? = nil
    @State private var showPurchaseError = false
    @State private var purchasedID: String? = nil

    var body: some View {
        ZStack {
            CosmicBackground()
            VStack(spacing: 0) {
                header
                tabPicker
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                ScrollView(showsIndicators: false) {
                    if selectedTab == .skins {
                        skinsContent
                    } else {
                        shieldsContent
                    }
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .onAppear { previewSkinID = store.activeSkinID }
        .confirmationDialog(
            buyDialogTitle,
            isPresented: Binding(get: { showBuyConfirm != nil },
                                 set: { if !$0 { showBuyConfirm = nil } }),
            titleVisibility: .visible
        ) {
            if let skin = showBuyConfirm {
                Button(L10n.shopBuyConfirm) { confirmBuy(skin) }
                Button(L10n.cancel, role: .cancel) {}
            }
        }
        .alert(L10n.shopNotEnoughLY, isPresented: $showPurchaseError) {
            Button(L10n.ok, role: .cancel) {}
        }
    }

    // MARK: Header
    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.shopTitle)
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)
                Text(L10n.shopSubtitle)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer()
            LYBadge(amount: store.totalDistance)
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 4)
    }

    // MARK: Tab picker
    private var tabPicker: some View {
        HStack(spacing: 8) {
            ForEach(ShopTab.allCases, id: \.self) { tab in
                Button { withAnimation(.spring(response: 0.3)) { selectedTab = tab } } label: {
                    HStack(spacing: 6) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 13, weight: .semibold))
                        Text(tab.label)
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        selectedTab == tab
                            ? AnyShapeStyle(Theme.primaryGradient)
                            : AnyShapeStyle(Theme.surface),
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                    )
                    .foregroundStyle(selectedTab == tab
                        ? Color(red: 0.04, green: 0.06, blue: 0.18)
                        : Theme.textSecondary)
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Theme.surfaceStroke, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: Skins content
    private var skinsContent: some View {
        VStack(spacing: 20) {
            skinPreviewCard
                .padding(.horizontal, 20)
                .padding(.top, 16)
            skinGrid
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
        }
    }

    // Live preview of selected skin
    private var skinPreviewCard: some View {
        let skin = SkinCatalog.skin(id: previewSkinID)
        let owned = store.ownedSkinIDs.contains(skin.id)
        let isActive = store.activeSkinID == skin.id
        return ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Theme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(
                            LinearGradient(colors: [skin.accentColor.opacity(0.6), skin.visorColor.opacity(0.4)],
                                           startPoint: .topLeading, endPoint: .bottomTrailing),
                            lineWidth: 1.5
                        )
                )
            VStack(spacing: 14) {
                SkinAstronautPreview(skin: skin, size: 130)
                    .padding(.top, 20)
                VStack(spacing: 4) {
                    HStack(spacing: 8) {
                        Text(skin.name)
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundStyle(Theme.textPrimary)
                        RarityBadge(rarity: skin.rarity)
                    }
                    unlockLabel(skin: skin)
                }
                if owned {
                    Button {
                        if !isActive { store.equipSkin(skin.id) }
                    } label: {
                        Text(isActive ? L10n.shopEquipped : L10n.shopEquip)
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(isActive
                                ? Color(red: 0.04, green: 0.06, blue: 0.18)
                                : Theme.textPrimary)
                            .frame(maxWidth: .infinity).frame(height: 44)
                            .background(
                                isActive ? AnyShapeStyle(Theme.primaryGradient) : AnyShapeStyle(Theme.surface),
                                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                            )
                            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Theme.surfaceStroke, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .disabled(isActive)
                    .animation(.spring(response: 0.25), value: store.activeSkinID)
                } else {
                    buyButton(skin: skin)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
    }

    @ViewBuilder private func unlockLabel(skin: AstronautSkin) -> some View {
        switch skin.unlock {
        case .free:
            Label(L10n.shopFree, systemImage: "checkmark.seal.fill")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.auroraMint)
        case .lightYears(let cost):
            Label("\(cost) \(L10n.shopLYCost)", systemImage: "warp.drive")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.starGold)
        case .iap:
            Label(L10n.shopPremium, systemImage: "crown.fill")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.nebulaPink)
        }
    }

    @ViewBuilder private func buyButton(skin: AstronautSkin) -> some View {
        switch skin.unlock {
        case .free:
            EmptyView()
        case .lightYears(let cost):
            let canAfford = store.totalDistance >= cost
            Button { showBuyConfirm = skin } label: {
                HStack(spacing: 6) {
                    Image(systemName: "warp.drive")
                    Text("\(cost) \(L10n.lightYrs)")
                }
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(canAfford ? Color(red: 0.04, green: 0.06, blue: 0.18) : Theme.textSecondary)
                .frame(maxWidth: .infinity).frame(height: 44)
                .background(
                    canAfford ? AnyShapeStyle(LinearGradient(colors: [Theme.starGold, Color(red: 0.97, green: 0.55, blue: 0.12)],
                                                              startPoint: .leading, endPoint: .trailing))
                             : AnyShapeStyle(Theme.surface),
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                )
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(canAfford ? Theme.starGold.opacity(0.5) : Theme.surfaceStroke, lineWidth: 1))
            }
            .buttonStyle(.plain)
        case .iap:
            Button { /* IAP flow — handled by ShopIAPManager */ } label: {
                HStack(spacing: 6) {
                    Image(systemName: "crown.fill")
                    Text(L10n.shopGetPremium)
                }
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(Color(red: 0.04, green: 0.06, blue: 0.18))
                .frame(maxWidth: .infinity).frame(height: 44)
                .background(
                    LinearGradient(colors: [Theme.nebulaPink, Theme.nebulaPurple],
                                   startPoint: .leading, endPoint: .trailing),
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                )
            }
            .buttonStyle(.plain)
        }
    }

    // Grid of all skins
    private var skinGrid: some View {
        let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
        return LazyVGrid(columns: columns, spacing: 12) {
            ForEach(SkinCatalog.all) { skin in
                SkinGridCell(skin: skin,
                             isOwned: store.ownedSkinIDs.contains(skin.id),
                             isActive: store.activeSkinID == skin.id,
                             isPreview: previewSkinID == skin.id)
                    .onTapGesture { withAnimation(.spring(response: 0.25)) { previewSkinID = skin.id } }
            }
        }
    }

    // MARK: Shields content
    private var shieldsContent: some View {
        VStack(spacing: 20) {
            shieldStatusCard
                .padding(.horizontal, 20)
                .padding(.top, 16)
            shieldPacksList
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
        }
    }

    private var shieldStatusCard: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Theme.surface)
                .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Theme.auroraCyan.opacity(0.3), lineWidth: 1.5))
            HStack(spacing: 20) {
                ZStack {
                    Circle().fill(Theme.auroraCyan.opacity(0.15)).frame(width: 72, height: 72)
                    Image(systemName: "shield.fill")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(Theme.auroraCyan)
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text(L10n.shopShieldsOwned)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.textSecondary)
                    Text("\(store.shieldCount)")
                        .font(.system(size: 38, weight: .black, design: .rounded))
                        .foregroundStyle(Theme.textPrimary)
                    Text(L10n.shopShieldsHint)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
            }
            .padding(20)
        }
    }

    private var shieldPacksList: some View {
        VStack(spacing: 12) {
            ForEach(SkinCatalog.shieldPacks) { pack in
                ShieldPackRow(pack: pack) {
                    // IAP flow placeholder — ShopIAPManager will handle it
                    store.addShields(pack.count)   // demo grant for prototype
                }
            }
        }
    }

    // MARK: Helpers
    private var buyDialogTitle: String {
        guard let skin = showBuyConfirm else { return "" }
        if case .lightYears(let cost) = skin.unlock {
            return "\(L10n.shopBuyTitle) \(skin.name)? \(cost) \(L10n.lightYrs)"
        }
        return ""
    }

    private func confirmBuy(_ skin: AstronautSkin) {
        if store.buySkin(skin) {
            withAnimation { purchasedID = skin.id }
            previewSkinID = skin.id
        } else {
            showPurchaseError = true
        }
        showBuyConfirm = nil
    }
}

// MARK: - ShopTab

enum ShopTab: CaseIterable {
    case skins, shields
    var label: String {
        switch self {
        case .skins:   return L10n.shopTabSkins
        case .shields: return L10n.shopTabShields
        }
    }
    var icon: String {
        switch self {
        case .skins:   return "tshirt.fill"
        case .shields: return "shield.fill"
        }
    }
}

// MARK: - LY currency badge

struct LYBadge: View {
    let amount: Int
    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "warp.drive")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Theme.starGold)
            Text("\(amount)")
                .font(.system(size: 15, weight: .black, design: .rounded))
                .foregroundStyle(Theme.starGold)
            Text(L10n.lightYrs)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.starGold.opacity(0.75))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(Theme.starGold.opacity(0.12), in: Capsule())
        .overlay(Capsule().stroke(Theme.starGold.opacity(0.3), lineWidth: 1))
    }
}

// MARK: - Rarity badge

struct RarityBadge: View {
    let rarity: SkinRarity
    var body: some View {
        Text(rarity.label)
            .font(.system(size: 9, weight: .black, design: .rounded))
            .foregroundStyle(rarity.color)
            .padding(.horizontal, 6).padding(.vertical, 3)
            .background(rarity.color.opacity(0.15), in: Capsule())
            .overlay(Capsule().stroke(rarity.color.opacity(0.4), lineWidth: 1))
    }
}

// MARK: - Skin preview astronaut (SwiftUI, skinnable)

struct SkinAstronautPreview: View {
    let skin: AstronautSkin
    var size: CGFloat = 140
    @State private var floatUp = false

    var body: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(
                    colors: [skin.visorColor.opacity(0.35), .clear],
                    center: .center, startRadius: 0, endRadius: size * 0.7
                ))
                .frame(width: size * 1.6, height: size * 1.6)
            skinBody
                .frame(width: size, height: size)
                .offset(y: floatUp ? -8 : 8)
                .animation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true), value: floatUp)
        }
        .onAppear { floatUp = true }
    }

    private var skinBody: some View {
        ZStack {
            // Backpack
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(skin.accentColor.opacity(0.9))
                .frame(width: size * 0.30, height: size * 0.32)
                .offset(y: size * 0.14)

            // Body
            RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                .fill(skin.suitColor)
                .frame(width: size * 0.72, height: size * 0.50)
                .overlay(RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                    .stroke(skin.accentColor.opacity(0.5), lineWidth: 1.5))
                .offset(y: size * 0.18)

            // Arms
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(skin.accentColor)
                .frame(width: size * 0.14, height: size * 0.10)
                .offset(x: -size * 0.32, y: size * 0.20)
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(skin.accentColor)
                .frame(width: size * 0.14, height: size * 0.10)
                .offset(x: size * 0.32, y: size * 0.20)

            // Helmet
            ZStack {
                Circle()
                    .fill(skin.suitColor)
                    .frame(width: size * 0.62, height: size * 0.62)
                    .overlay(Circle().stroke(skin.accentColor.opacity(0.5), lineWidth: 1.5))

                // Visor
                Ellipse()
                    .fill(LinearGradient(
                        colors: [skin.visorColor.opacity(0.95), skin.visorColor.opacity(0.6)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ))
                    .frame(width: size * 0.38, height: size * 0.30)

                // Visor shine
                Capsule()
                    .fill(Color.white.opacity(0.55))
                    .frame(width: size * 0.10, height: size * 0.06)
                    .offset(x: -size * 0.10, y: -size * 0.10)
            }
            .offset(y: -size * 0.20)

            // Chest panel
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(skin.accentColor)
                .frame(width: size * 0.20, height: size * 0.08)
                .offset(y: size * 0.14)

            // Antenna
            Capsule().fill(skin.suitColor)
                .frame(width: size * 0.03, height: size * 0.12)
                .offset(y: -size * 0.52)
            Circle().fill(skin.visorColor)
                .frame(width: size * 0.07, height: size * 0.07)
                .offset(y: -size * 0.58)
                .shadow(color: skin.visorColor.opacity(0.8), radius: 6)
        }
    }
}

// MARK: - Skin grid cell

struct SkinGridCell: View {
    let skin: AstronautSkin
    let isOwned: Bool
    let isActive: Bool
    let isPreview: Bool

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 8) {
                SkinAstronautPreview(skin: skin, size: 72)
                    .frame(height: 90)
                Text(skin.name)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity)
                priceTag
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity)
            .background(
                isPreview ? AnyShapeStyle(LinearGradient(
                    colors: [skin.accentColor.opacity(0.22), skin.visorColor.opacity(0.10)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )) : AnyShapeStyle(Theme.surface),
                in: RoundedRectangle(cornerRadius: 18, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(
                        isPreview ? skin.accentColor.opacity(0.7) : Theme.surfaceStroke,
                        lineWidth: isPreview ? 2 : 1
                    )
            )

            if isActive {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Theme.auroraMint)
                    .padding(8)
            } else if isOwned {
                Image(systemName: "lock.open.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Theme.textTertiary)
                    .padding(8)
            }
        }
    }

    @ViewBuilder private var priceTag: some View {
        switch skin.unlock {
        case .free:
            Text(L10n.shopFree)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.auroraMint)
        case .lightYears(let cost):
            HStack(spacing: 3) {
                Image(systemName: "warp.drive").font(.system(size: 10))
                Text("\(cost)").font(.system(size: 11, weight: .bold, design: .rounded))
            }
            .foregroundStyle(isOwned ? Theme.textTertiary : Theme.starGold)
        case .iap:
            HStack(spacing: 3) {
                Image(systemName: "crown.fill").font(.system(size: 10))
                Text(L10n.shopPremium).font(.system(size: 11, weight: .bold, design: .rounded))
            }
            .foregroundStyle(isOwned ? Theme.textTertiary : Theme.nebulaPink)
        }
    }
}

// MARK: - Shield pack row

struct ShieldPackRow: View {
    let pack: ShieldPack
    let onBuy: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle().fill(Theme.auroraCyan.opacity(0.15)).frame(width: 52, height: 52)
                Image(systemName: pack.icon)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(Theme.auroraCyan)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(pack.name)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)
                Text("\(pack.count) \(L10n.shopShieldsUnit)")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer()
            Button(action: onBuy) {
                Text(pack.price)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(red: 0.04, green: 0.06, blue: 0.18))
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .background(Theme.primaryGradient, in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
            .stroke(Theme.surfaceStroke, lineWidth: 1))
    }
}

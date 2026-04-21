import SwiftUI

/**
 * Full-screen carousel shown before the normal tour welcome card.
 *
 * Supports horizontal (default) and vertical swipe via `carousel.direction`.
 * Navigation is also available via dot row (tap to jump) and prev/next buttons.
 *
 * Callbacks:
 * - `onDone`    — last slide completed (Next → Done tapped)
 * - `onDismiss` — ✕ dismiss button tapped (any slide)
 */
public struct TTSplashCarouselView: View {
    let carousel: TTSplashCarousel
    let onDone: () -> Void
    let onDismiss: () -> Void

    @State private var currentIndex: Int = 0

    private var slides: [TTCarouselSlide] { carousel.slides }
    private var isVertical: Bool { carousel.direction == "vertical" }

    private var bgColor: Color {
        UIColor(hex: carousel.bgColor ?? "")
            .map { Color($0) } ?? Color(red: 0.102, green: 0.102, blue: 0.173)
    }

    private var textColor: Color {
        UIColor(hex: carousel.textColor ?? "")
            .map { Color($0) } ?? .white
    }

    public init(carousel: TTSplashCarousel, onDone: @escaping () -> Void, onDismiss: @escaping () -> Void) {
        self.carousel = carousel
        self.onDone = onDone
        self.onDismiss = onDismiss
    }

    public var body: some View {
        GeometryReader { geo in
            ZStack {
                bgColor.ignoresSafeArea()

                // ── Slide pager ───────────────────────────────────────────────
                if isVertical {
                    TTVerticalPager(
                        pageCount: slides.count,
                        currentPage: $currentIndex
                    ) { i in
                        SlideContentView(slide: slides[i], textColor: textColor, containerWidth: geo.size.width)
                            .frame(width: geo.size.width, height: geo.size.height)
                    }
                    .ignoresSafeArea()
                } else {
                    TabView(selection: $currentIndex) {
                        ForEach(0 ..< slides.count, id: \.self) { i in
                            SlideContentView(slide: slides[i], textColor: textColor, containerWidth: geo.size.width)
                                .tag(i)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .ignoresSafeArea()
                }

                // ── Dismiss button ────────────────────────────────────────────
                VStack {
                    HStack {
                        Spacer()
                        Button(action: onDismiss) {
                            ZStack {
                                Circle()
                                    .fill(Color.white.opacity(0.2))
                                    .frame(width: 32, height: 32)
                                Text("✕")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(textColor)
                            }
                        }
                        .padding(.top, 56)
                        .padding(.trailing, 20)
                    }
                    Spacer()
                }
                .zIndex(1)

                // ── Bottom nav ────────────────────────────────────────────────
                VStack {
                    Spacer()
                    VStack(spacing: 16) {
                        // Dot row
                        HStack(spacing: 8) {
                            ForEach(0 ..< slides.count, id: \.self) { i in
                                Circle()
                                    .fill(i == currentIndex ? textColor : textColor.opacity(0.35))
                                    .frame(
                                        width:  i == currentIndex ? 10 : 7,
                                        height: i == currentIndex ? 10 : 7
                                    )
                                    .onTapGesture { withAnimation(.easeInOut) { currentIndex = i } }
                            }
                        }
                        // Prev / Next-Done row
                        HStack {
                            if currentIndex > 0 {
                                Button(action: { withAnimation(.easeInOut) { currentIndex -= 1 } }) {
                                    Text("← Back")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(textColor.opacity(0.65))
                                }
                            } else {
                                Spacer().frame(width: 64)
                            }

                            Spacer()

                            Button(action: {
                                if currentIndex == slides.count - 1 { onDone() }
                                else { withAnimation(.easeInOut) { currentIndex += 1 } }
                            }) {
                                Text(currentIndex == slides.count - 1 ? "Done" : "Next →")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(bgColor)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 10)
                                    .background(textColor)
                                    .cornerRadius(8)
                            }
                        }
                        .padding(.horizontal, 24)
                    }
                    .padding(.bottom, 44)
                }
                .zIndex(1)
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - Vertical pager (custom DragGesture-based)

private struct TTVerticalPager<Content: View>: View {
    let pageCount: Int
    @Binding var currentPage: Int
    @ViewBuilder let content: (Int) -> Content

    @State private var dragOffset: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(0 ..< pageCount, id: \.self) { i in
                    content(i)
                        .offset(y: CGFloat(i - currentPage) * geo.size.height + dragOffset)
                }
            }
            .clipped()
            .gesture(
                DragGesture()
                    .onChanged { value in
                        dragOffset = value.translation.height
                    }
                    .onEnded { value in
                        let threshold = geo.size.height * 0.25
                        withAnimation(.easeInOut(duration: 0.35)) {
                            dragOffset = 0
                            if value.translation.height < -threshold, currentPage < pageCount - 1 {
                                currentPage += 1
                            } else if value.translation.height > threshold, currentPage > 0 {
                                currentPage -= 1
                            }
                        }
                    }
            )
        }
    }
}

// MARK: - Single slide content

private struct SlideContentView: View {
    let slide: TTCarouselSlide
    let textColor: Color
    let containerWidth: CGFloat

    /// Logo width = min(50% of container, 400pt); height = width / 2 (2:1 ratio)
    private var logoWidth: CGFloat { min(containerWidth * 0.5, 400) }
    private var logoHeight: CGFloat { logoWidth / 2 }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                Spacer().frame(height: 100)

                // Logo
                if let logoUrl = slide.logoUrl, !logoUrl.isEmpty {
                    AsyncImage(url: URL(string: logoUrl)) { phase in
                        switch phase {
                        case .success(let img): img.resizable().scaledToFit()
                        default: Color.white.opacity(0.08).frame(width: logoWidth, height: logoHeight)
                        }
                    }
                    .frame(width: logoWidth, height: logoHeight)
                    .padding(.bottom, 20)
                }

                // Slide image
                if let imgUrl = slide.imageUrl, !imgUrl.isEmpty {
                    AsyncImage(url: URL(string: imgUrl)) { phase in
                        switch phase {
                        case .success(let img): img.resizable().scaledToFill()
                        default: Color.white.opacity(0.05)
                        }
                    }
                    .aspectRatio(1, contentMode: .fit)
                    .clipped()
                    .cornerRadius(12)
                    .padding(.horizontal, 28)
                    .padding(.bottom, 24)
                }

                // Title
                if let title = slide.title, !title.isEmpty {
                    Text(title)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(textColor)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 28)
                        .padding(.bottom, 12)
                }

                // Description
                if let desc = slide.description, !desc.isEmpty {
                    Text(desc)
                        .font(.system(size: 15))
                        .foregroundColor(textColor.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .padding(.horizontal, 28)
                }

                Spacer().frame(height: 160) // space for bottom nav
            }
        }
    }
}

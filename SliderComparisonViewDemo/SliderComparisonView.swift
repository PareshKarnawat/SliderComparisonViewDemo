import SwiftUI

public struct SliderComparisonView<Left: View, Right: View>: View {
    
    private var indicatorImage: Image = Image(systemName: "arrow.down.left.and.arrow.up.right")
    private var indicatorImageWidth: CGFloat = 22
    private var indicatorImageColor: Color = .gray
    private var indicatorColor: Color = .white
    private var indicatorWidth: CGFloat = 44
    private var dividerColor: Color = .white
    private var dividerWidth: CGFloat = 2
    private let lhs: () -> Left
    private let rhs: () -> Right
    
    @State private var progress: CGFloat = 0.5
    
    public init(
        @ViewBuilder lhs: @escaping () -> Left,
        @ViewBuilder rhs: @escaping () -> Right
    ) {
        self.lhs = lhs
        self.rhs = rhs
    }
    
    public var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            ZStack {
                rhs()
                lhs()
                    .mask(
                        SlidingDiagonalMask(progress: progress)
                            .frame(width: size.width, height: size.height)
                    )
                
                SlidingDiagonalDivider(progress: progress)
                    .stroke(dividerColor, lineWidth: dividerWidth)
                    .frame(width: size.width, height: size.height)
                
                SlidingDiagonalHandle(
                    progress: $progress,
                    indicatorImage: indicatorImage,
                    indicatorImageWidth: indicatorImageWidth,
                    indicatorImageColor: indicatorImageColor,
                    indicatorColor: indicatorColor,
                    indicatorWidth: indicatorWidth
                )
                .frame(width: size.width, height: size.height)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        let x = max(0, min(size.width, gesture.location.x))
                        self.progress = 1 - x / size.width
                    }
            )
        }
        .ignoresSafeArea()
    }
}

private struct SlidingDiagonalGeometry {
    static func slope(in rect: CGRect) -> CGFloat {
        rect.height / rect.width
    }
    
    static func intercept(for progress: CGFloat, in rect: CGRect) -> CGFloat {
        let p = max(0, min(1, progress))
        return (p - 0.5) * 2 * rect.height
    }
    
    static func y(at x: CGFloat, m: CGFloat, c: CGFloat) -> CGFloat { m * x + c }
    
    static func intersections(in rect: CGRect, m: CGFloat, c: CGFloat) -> [CGPoint] {
        var points: [CGPoint] = []
        
        let yL = c
        if yL >= rect.minY && yL <= rect.maxY {
            points.append(CGPoint(x: rect.minX, y: yL))
        }
        
        let yR = m * rect.width + c
        if yR >= rect.minY && yR <= rect.maxY {
            points.append(CGPoint(x: rect.maxX, y: yR))
        }
        
        if m != 0 {
            let xT = -c / m
            if xT >= rect.minX && xT <= rect.maxX {
                points.append(CGPoint(x: xT, y: rect.minY))
            }
        }
        
        if m != 0 {
            let xB = (rect.height - c) / m
            if xB >= rect.minX && xB <= rect.maxX {
                points.append(CGPoint(x: xB, y: rect.maxY))
            }
        }
        
        func key(_ p: CGPoint) -> String { "\(round(p.x*1000))/\(round(p.y*1000))" }
        var seen = Set<String>()
        var unique: [CGPoint] = []
        for p in points {
            let k = key(p)
            if !seen.contains(k) {
                seen.insert(k)
                unique.append(p)
            }
        }
        if unique.count > 2 {
            unique.sort { (a, b) in
                if a.x == b.x { return a.y < b.y }
                return a.x < b.x
            }
            unique = [unique.first!, unique.last!]
        }
        return unique
    }
}

private struct SlidingDiagonalMask: Shape {
    var progress: CGFloat
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let m = SlidingDiagonalGeometry.slope(in: rect)
        let c = SlidingDiagonalGeometry.intercept(for: progress, in: rect)
        
        let pts = SlidingDiagonalGeometry.intersections(in: rect, m: m, c: c)
        guard pts.count == 2 else {
            return path
        }
        let p1 = pts[0]
        let p2 = pts[1]
        
        func isBelowOrOn(_ p: CGPoint) -> Bool { p.y >= m * p.x + c - 0.5 }
        
        var poly: [CGPoint] = [p1, p2]
        let corners = [CGPoint(x: rect.maxX, y: rect.maxY),
                       CGPoint(x: rect.minX, y: rect.maxY),
                       CGPoint(x: rect.maxX, y: rect.minY),
                       CGPoint(x: rect.minX, y: rect.minY)]
        for corner in corners where isBelowOrOn(corner) {
            poly.append(corner)
        }
        let cx = poly.map { $0.x }.reduce(0, +) / CGFloat(poly.count)
        let cy = poly.map { $0.y }.reduce(0, +) / CGFloat(poly.count)
        poly.sort { (a, b) in
            let aa = atan2(a.y - cy, a.x - cx)
            let bb = atan2(b.y - cy, b.x - cx)
            return aa < bb
        }
        
        if let first = poly.first {
            path.move(to: first)
            for p in poly.dropFirst() { path.addLine(to: p) }
            path.closeSubpath()
        }
        return path
    }
    
    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }
}

private struct SlidingDiagonalDivider: Shape {
    var progress: CGFloat
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let m = SlidingDiagonalGeometry.slope(in: rect)
        let c = SlidingDiagonalGeometry.intercept(for: progress, in: rect)
        let pts = SlidingDiagonalGeometry.intersections(in: rect, m: m, c: c)
        guard pts.count == 2 else { return path }
        path.move(to: pts[0])
        path.addLine(to: pts[1])
        return path
    }
    
    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }
}

private struct SlidingDiagonalHandle: View {
    @Binding var progress: CGFloat
    let indicatorImage: Image
    let indicatorImageWidth: CGFloat
    let indicatorImageColor: Color
    let indicatorColor: Color
    let indicatorWidth: CGFloat
    
    var body: some View {
        GeometryReader { geo in
            let rect = CGRect(origin: .zero, size: geo.size)
            let m = SlidingDiagonalGeometry.slope(in: rect)
            let c = SlidingDiagonalGeometry.intercept(for: progress, in: rect)
            let pts = SlidingDiagonalGeometry.intersections(in: rect, m: m, c: c)
            let center: CGPoint = {
                if pts.count == 2 {
                    return CGPoint(x: (pts[0].x + pts[1].x) / 2, y: (pts[0].y + pts[1].y) / 2)
                } else {
                    return CGPoint(x: rect.midX, y: rect.midY)
                }
            }()
            
            Circle()
                .fill(indicatorColor)
                .frame(width: indicatorWidth, height: indicatorWidth)
                .overlay {
                    indicatorImage
                        .resizable()
                        .scaledToFit()
                        .frame(width: indicatorImageWidth, height: indicatorImageWidth)
                        .foregroundColor(indicatorImageColor)
                }
                .position(center)
        }
    }
}

extension SliderComparisonView {
    public func indicatorImage(_ image: Image) -> Self {
        var copy = self
        copy.indicatorImage = image
        return copy
    }
    
    public func indicatorImageColor(_ color: Color) -> Self {
        var copy = self
        copy.indicatorImageColor = color
        return copy
    }
    
    public func indicatorImageWidth(_ width: CGFloat) -> Self {
        var copy = self
        copy.indicatorImageWidth = width
        return copy
    }
    
    public func indicatorColor(_ color: Color) -> Self {
        var copy = self
        copy.indicatorColor = color
        return copy
    }
    
    public func indicatorWidth(_ width: CGFloat) -> Self {
        var copy = self
        copy.indicatorWidth = width
        return copy
    }
    
    public func dividerColor(_ color: Color) -> Self {
        var copy = self
        copy.dividerColor = color
        return copy
    }
    
    public func dividerWidth(_ width: CGFloat) -> Self {
        var copy = self
        copy.dividerWidth = width
        return copy
    }
    
    public func initialProgress(_ progress: CGFloat) -> Self {
        var copy = self
        copy._progress = State(initialValue: max(0, min(1, progress)))
        return copy
    }
}

#Preview {
    SliderComparisonView(
        lhs: {
            ZStack {
                Image("BWNature")
                    .resizable()
            }
        },
        rhs: {
            ZStack {
                Image("Nature")
                    .resizable()
            }
        }
    )
    .indicatorImage(Image(systemName: "arrow.down.left.and.arrow.up.right"))
    .indicatorColor(.white)
    .indicatorImageColor(.black)
    .dividerColor(.white)
    .dividerWidth(2)
    .initialProgress(0.3)
}

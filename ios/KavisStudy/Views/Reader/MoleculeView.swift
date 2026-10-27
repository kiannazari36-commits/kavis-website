import SwiftUI
import SceneKit

/// Molecule viewer (web: components/MolViewer.tsx, design/MolViewer.dc.html): the structure in 3D that turns with a
/// finger, the functional groups below; a tap on a group lights its atoms up. Names are in the PDF's language.
struct MoleculeSheet: View {
    @Environment(AppPrefs.self) private var prefs
    @Environment(\.dismiss) private var dismiss
    let molecule: Molecule
    let page: Int
    let contentLang: Lang
    @State private var selected: String?

    private var lang: Lang { prefs.lang }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(prefs.t("molDrugPage", ["n": Format.num(page, lang)]))
                    .font(KFont.mono(11, .regular)).tracking(lang.isRTL ? 0 : 0.8).foregroundStyle(KPhone.text2)
                Spacer()
                Button { dismiss() } label: {
                    KIcon(name: .close, size: 16, width: 2).foregroundStyle(KPhone.text)
                        .frame(width: 38, height: 38).background(KPhone.card, in: Circle())
                        .overlay(Circle().stroke(KPhone.line, lineWidth: 1))
                }
                .accessibilityLabel(prefs.t("close"))
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(molecule.text(molecule.name, contentLang)).font(KFont.ui(22, .semibold, lang: contentLang)).foregroundStyle(KPhone.text)
                Text("\(molecule.formula) · \(molecule.text(molecule.mw, contentLang)) · \(molecule.text(molecule.cls, contentLang))")
                    .font(KFont.mono(12, .regular)).foregroundStyle(KPhone.text2)
            }
            MoleculeScene(molecule: molecule, lit: Set(molecule.groups.first { $0.id == selected }?.atoms ?? []))
                .frame(height: 260)
                .background(KPhone.card, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(KPhone.line, lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(molecule.groups) { g in
                        let on = selected == g.id
                        Button { selected = on ? nil : g.id } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(molecule.text(g.name, contentLang)).font(KFont.ui(14, .semibold, lang: contentLang)).foregroundStyle(on ? KPhone.ctaText : KPhone.text)
                                if on {
                                    Text(molecule.text(g.note, contentLang)).font(KFont.ui(13, lang: contentLang)).foregroundStyle(KPhone.ctaText.opacity(0.92))
                                        .multilineTextAlignment(.leading)
                                }
                            }
                            .environment(\.layoutDirection, contentLang.layoutDirection)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(14)
                            .background(on ? KPhone.navActive : KPhone.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(KPhone.line, lineWidth: on ? 0 : 1))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(.horizontal, 20).padding(.top, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(KPhone.authBg.ignoresSafeArea())
    }
}

/// The 3D scene: a ball for every atom, a rod for every bond (two thin rods for a double bond). The 2D positions of
/// the library are the x / y of the balls; `allowsCameraControl` lets the finger turn and zoom it.
private struct MoleculeScene: UIViewRepresentable {
    let molecule: Molecule
    let lit: Set<String>

    private static func color(_ element: String) -> UIColor {
        switch element {
        case "O": UIColor(red: 0.85, green: 0.18, blue: 0.2, alpha: 1)
        case "N": UIColor(red: 0.2, green: 0.4, blue: 0.85, alpha: 1)
        case "S": UIColor(red: 0.93, green: 0.75, blue: 0.15, alpha: 1)
        default: UIColor(red: 0.35, green: 0.33, blue: 0.31, alpha: 1)
        }
    }

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        view.backgroundColor = .clear
        view.allowsCameraControl = true
        view.autoenablesDefaultLighting = true
        view.antialiasingMode = .multisampling4X
        view.scene = build()
        return view
    }

    func updateUIView(_ view: SCNView, context: Context) {
        // Only the highlight changes: the atoms of the chosen group glow.
        view.scene?.rootNode.childNodes.filter { $0.name?.hasPrefix("atom:") == true }.forEach { node in
            let id = String(node.name!.dropFirst(5))
            node.geometry?.firstMaterial?.emission.contents = lit.contains(id) ? UIColor(red: 0.95, green: 0.7, blue: 0.24, alpha: 1) : UIColor.black
            node.scale = lit.contains(id) ? SCNVector3(1.3, 1.3, 1.3) : SCNVector3(1, 1, 1)
        }
    }

    private func position(_ a: Molecule.Atom) -> SCNVector3 {
        let c = molecule.center ?? [150, 150]
        return SCNVector3(Float((a.x - c[0]) / 40), Float(-(a.y - c[1]) / 40), 0)
    }

    private func build() -> SCNScene {
        let scene = SCNScene()
        let root = scene.rootNode
        for (id, atom) in molecule.atoms {
            let ball = SCNSphere(radius: atom.element == "C" ? 0.2 : 0.26)
            ball.firstMaterial?.diffuse.contents = Self.color(atom.element)
            ball.firstMaterial?.specular.contents = UIColor.white
            let node = SCNNode(geometry: ball)
            node.name = "atom:\(id)"
            node.position = position(atom)
            root.addChildNode(node)
        }
        for bond in molecule.bonds {
            guard let a = molecule.atoms[bond.from], let b = molecule.atoms[bond.to] else { continue }
            let p = position(a), q = position(b)
            for offset in (bond.order == 2 ? [Float(-0.07), 0.07] : [0]) {
                root.addChildNode(rod(from: p, to: q, offset: offset, radius: bond.order == 2 ? 0.035 : 0.06))
            }
        }
        let camera = SCNNode()
        camera.camera = SCNCamera()
        camera.camera?.fieldOfView = 40
        camera.position = SCNVector3(0, 0, 8)
        root.addChildNode(camera)
        return scene
    }

    private func rod(from p: SCNVector3, to q: SCNVector3, offset: Float, radius: CGFloat) -> SCNNode {
        let dx = q.x - p.x, dy = q.y - p.y
        let length = sqrt(dx * dx + dy * dy)
        let cylinder = SCNCylinder(radius: radius, height: CGFloat(length))
        cylinder.firstMaterial?.diffuse.contents = UIColor(white: 0.62, alpha: 1)
        let node = SCNNode(geometry: cylinder)
        // The cylinder stands along y: tilt it onto the bond and move a double bond's two rods apart.
        let nx = -dy / length, ny = dx / length
        node.position = SCNVector3((p.x + q.x) / 2 + nx * offset, (p.y + q.y) / 2 + ny * offset, 0)
        node.eulerAngles.z = atan2(dy, dx) - .pi / 2
        return node
    }
}

//
//  ContentView.swift
//  YellowDot
//
//  Created by Alin Panaitiu on 21.12.2021.
//

import SwiftUI

// MARK: - CheckboxToggleStyle

struct CheckboxToggleStyle: ToggleStyle {
    enum Style {
        case square, circle

        // MARK: Internal

        var sfSymbolName: String {
            switch self {
            case .square:
                return "square"
            case .circle:
                return "circle"
            }
        }
    }

    @Environment(\.isEnabled) var isEnabled
    let style: Style // custom param

    func makeBody(configuration: Configuration) -> some View {
        Button(action: {
            configuration.isOn.toggle() // toggle the state binding
        }, label: {
            HStack {
                Image(systemName: configuration.isOn ? "checkmark.\(style.sfSymbolName).fill" : style.sfSymbolName)
                    .imageScale(.large)
                configuration.label
            }
        })
        .buttonStyle(PlainButtonStyle()) // remove any implicit styling from the button
        .disabled(!isEnabled)
    }
}

// MARK: - FlatButton

struct FlatButton: ButtonStyle {
    // MARK: Lifecycle

    init(
        color: Color? = nil,
        textColor: Color? = nil,
        hoverColor: Color? = nil,
        colorBinding: Binding<Color>? = nil,
        textColorBinding: Binding<Color>? = nil,
        hoverColorBinding: Binding<Color>? = nil
    ) {
        _color = colorBinding ?? .constant(color ?? red)
        _textColor = textColorBinding ?? .constant(textColor ?? .primary)
        _hoverColor = hoverColorBinding ??
            .constant(hoverColor ?? Color(NSColor(red).blended(withFraction: 0.7, of: .white)!))
    }

    // MARK: Internal

    @Binding var color: Color
    @Binding var textColor: Color
    @State var colorMultiply: Color = .white
    @State var scale: CGFloat = 1.0
    @Binding var hoverColor: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration
            .label
            .foregroundColor(textColor)
            .padding(.vertical, 4.0)
            .padding(.horizontal, 8.0)
            .background(
                RoundedRectangle(
                    cornerRadius: 8,
                    style: .continuous
                ).fill(color)

            ).colorMultiply(colorMultiply)
            .scaleEffect(scale)
            .onHover(perform: { hover in
                withAnimation(.easeOut(duration: 0.2)) {
                    colorMultiply = hover ? hoverColor : .white
                    scale = hover ? 1.05 : 1
                }
            })
    }
}

import Defaults
import LaunchAtLogin

let WINDOW_WIDTH: CGFloat = 300
let WINDOW_PADDING_HORIZONTAL: CGFloat = 40
let FULL_WINDOW_WIDTH = WINDOW_WIDTH + WINDOW_PADDING_HORIZONTAL * 2

// MARK: - Semaphore

struct Semaphore: View {
    @State var xVisible = false

    var body: some View {
        HStack {
            Button(
                action: { AppDelegate.instance.statusBar?.hidePopover(AppDelegate.instance) },
                label: {
                    ZStack(alignment: .center) {
                        Circle().fill(Color.red).frame(width: 14, height: 14, alignment: .center)
                        Image(systemName: "xmark").font(.system(size: 8, weight: .bold))
                            .foregroundColor(.black.opacity(0.8))
                            .opacity(xVisible ? 1 : 0)
                    }
                }
            ).buttonStyle(.plain)
                .onHover { hover in withAnimation(.easeOut(duration: 0.15)) { xVisible = hover }}
            Circle().fill(Color.gray.opacity(0.3)).frame(width: 14, height: 14, alignment: .center)
            Circle().fill(Color.gray.opacity(0.3)).frame(width: 14, height: 14, alignment: .center)
        }.padding(.leading, -8)
            .padding(.top, -8)
            .padding(.bottom, 10)
    }
}

// MARK: - ContentView

struct ContentView: View {
    @Environment(\.colorScheme) var colorScheme
    @ObservedObject var launchAtLogin = LaunchAtLogin.observable
    @Default(.hideMenubarIcon) var hideMenubarIcon
    @Default(.paused) var paused
    @Default(.orange) var orange
    @State var orangeOpacity: CGFloat = 0

    var body: some View {
        VStack(alignment: .leading) {
            if hideMenubarIcon {
                Semaphore()
            }
            Text("Settings").font(.largeTitle).fontWeight(.black).padding(.bottom, 6)
            VStack(alignment: .leading, spacing: 5) {
                Toggle("Hide menubar icon", isOn: $hideMenubarIcon)
                    .toggleStyle(CheckboxToggleStyle(style: .circle))
                    .foregroundColor(.primary)
                Toggle("Launch at login", isOn: $launchAtLogin.isEnabled)
                    .toggleStyle(CheckboxToggleStyle(style: .circle))
                    .foregroundColor(.primary)
                Toggle("It's not yellow! It is orange!", isOn: $orange)
                    .toggleStyle(CheckboxToggleStyle(style: .circle))
                    .foregroundColor(.primary)
                VStack(alignment: .leading, spacing: 1) {
                    Text(#"Well yeah, maybe, I don't know.."#).font(.caption.weight(.semibold))
                    Text(#"it looks kinda yellow to me ¯\\_(ツ)_/¯"#).font(.caption.weight(.semibold))
                }.opacity(orangeOpacity).padding(.leading, 28)
            }.padding(.leading)
                .onChange(of: orange) { isOrange in
                    guard isOrange else {
                        withAnimation { orangeOpacity = 0 }
                        return
                    }
                    withAnimation(.easeOut(duration: 0.5)) { orangeOpacity = 1 }
                    withAnimation(.easeIn(duration: 1.5).delay(5)) { orangeOpacity = 0 }
                }
            ZStack(alignment: .center) {
                HStack {
                    Button(paused ? "Start" : "Pause") {
                        paused.toggle()
                    }
                    .buttonStyle(FlatButton(color: .orange, textColor: inverted))
                    .font(.system(size: 13, weight: .semibold))
                    .keyboardShortcut(KeyEquivalent("q"), modifiers: [.command])
                    Spacer()
                    Button("Quit") {
                        NSApplication.shared.terminate(self)
                    }
                    .buttonStyle(FlatButton(color: red, textColor: inverted))
                    .font(.system(size: 13, weight: .semibold))
                    .keyboardShortcut(KeyEquivalent("q"), modifiers: [.command])
                }
                Text(paused ? "Hiding paused" : "Hiding \(orange ? "orange" : "yellow") dot")
                    .font(.caption.weight(.heavy))
                    .foregroundColor(.primary.opacity(0.3))
            }.frame(maxWidth: .infinity)
        }.frame(width: WINDOW_WIDTH)
            .padding(.horizontal, WINDOW_PADDING_HORIZONTAL)
            .padding(.bottom, 40)
            .padding(.top, 20)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(inverted)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                    .shadow(color: blackMauve.opacity(colorScheme == .dark ? 0.5 : 0.3), radius: 4, x: 0, y: 4)
            )
    }
}

// MARK: - ContentView_Previews

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            ContentView()
            ContentView()
                .preferredColorScheme(.light)
        }
    }
}

let red = Color(hue: 0.98, saturation: 0.82, brightness: 1.00)
let lightGold = Color(hue: 0.09, saturation: 0.28, brightness: 0.94)
let mauve = Color(hue: 252 / 360, saturation: 0.29, brightness: 0.23)
let blackMauve = Color(hue: 252 / 360, saturation: 0.08, brightness: 0.12)
let darkGray = Color(hue: 0, saturation: 0.01, brightness: 0.32)
let blackGray = Color(hue: 0.03, saturation: 0.12, brightness: 0.18)
let lightGray = Color(hue: 0, saturation: 0.0, brightness: 0.92)
let yellow = Color(hue: 39 / 360, saturation: 1.0, brightness: 0.64)
let blue = Color(hue: 214 / 360, saturation: 1.0, brightness: 0.54)
let green = Color(hue: 141 / 360, saturation: 0.59, brightness: 0.58)

let accent = lightGold
var inverted: Color { Color("InvertedPrimary") }

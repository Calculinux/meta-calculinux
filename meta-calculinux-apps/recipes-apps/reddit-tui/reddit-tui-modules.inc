SRC_URI += "${GO_DEPENDENCIES_SRC_URI}"
GO_DEPENDENCIES_SRC_URI = "\
    ${@go_src_uri('github.com/charmbracelet/bubbletea','v1.2.4')} \
    ${@go_src_uri('github.com/charmbracelet/x','v0.0.0-20250303111204-ce812b082f54',path='github.com/charmbracelet/x/exp/teatest',subdir='exp/teatest')} \
    ${@go_src_uri('github.com/muesli/reflow','v0.3.0')} \
    ${@go_src_uri('go.googlesource.com/net','v0.39.0',path='golang.org/x/net')} \
    ${@go_src_uri('github.com/aymanbagabas/go-udiff','v0.2.0')} \
    ${@go_src_uri('github.com/charmbracelet/x','v0.0.0-20240815200342-61de596daa2b',path='github.com/charmbracelet/x/exp/golden',subdir='exp/golden')} \
    ${@go_src_uri('github.com/burntsushi/toml','v1.4.0',path='github.com/BurntSushi/toml')} \
    ${@go_src_uri('github.com/atotto/clipboard','v0.1.4')} \
    ${@go_src_uri('github.com/sahilm/fuzzy','v0.1.1')} \
    ${@go_src_uri('github.com/aymanbagabas/go-osc52','v2.0.1',path='github.com/aymanbagabas/go-osc52/v2',pathmajor='/v2')} \
    ${@go_src_uri('github.com/charmbracelet/bubbles','v0.20.0')} \
    ${@go_src_uri('github.com/charmbracelet/lipgloss','v1.0.0')} \
    ${@go_src_uri('github.com/charmbracelet/x','v0.4.5',path='github.com/charmbracelet/x/ansi',subdir='ansi')} \
    ${@go_src_uri('github.com/charmbracelet/x','v0.2.1',path='github.com/charmbracelet/x/term',subdir='term')} \
    ${@go_src_uri('github.com/erikgeiser/coninput','v0.0.0-20211004153227-1c3628e74d0f')} \
    ${@go_src_uri('github.com/lucasb-eyer/go-colorful','v1.2.0')} \
    ${@go_src_uri('github.com/mattn/go-isatty','v0.0.20')} \
    ${@go_src_uri('github.com/mattn/go-localereader','v0.0.1')} \
    ${@go_src_uri('github.com/mattn/go-runewidth','v0.0.16')} \
    ${@go_src_uri('github.com/muesli/ansi','v0.0.0-20230316100256-276c6243b2f6')} \
    ${@go_src_uri('github.com/muesli/cancelreader','v0.2.2')} \
    ${@go_src_uri('github.com/muesli/termenv','v0.15.2')} \
    ${@go_src_uri('github.com/rivo/uniseg','v0.4.7')} \
    ${@go_src_uri('go.googlesource.com/sync','v0.13.0',path='golang.org/x/sync')} \
    ${@go_src_uri('go.googlesource.com/sys','v0.32.0',path='golang.org/x/sys')} \
    ${@go_src_uri('go.googlesource.com/text','v0.24.0',path='golang.org/x/text')} \
"

# github.com/charmbracelet/bubbletea@v1.2.4 => 2ea49ddc4f36b8c47231ab0be31e40ca8676b050
SRCREV_github.com.charmbracelet.bubbletea = "2ea49ddc4f36b8c47231ab0be31e40ca8676b050"
# github.com/charmbracelet/x/exp/teatest@v0.0.0-20250303111204-ce812b082f54 => ce812b082f548a1a39b1a2bab82d931514ee89d8
SRCREV_github.com.charmbracelet.x.exp.teatest = "ce812b082f548a1a39b1a2bab82d931514ee89d8"
# github.com/muesli/reflow@v0.3.0 => 602e329532049c9e33fa8c74e352a46fb9486947
SRCREV_github.com.muesli.reflow = "602e329532049c9e33fa8c74e352a46fb9486947"
# golang.org/x/net@v0.39.0 => b8d88774daf2a7cf137dad5173fc9bb981fc18fb
SRCREV_golang.org.x.net = "b8d88774daf2a7cf137dad5173fc9bb981fc18fb"
# github.com/aymanbagabas/go-udiff@v0.2.0 => 4ad777e23c62c40120812548719a9d734b9c39ac
SRCREV_github.com.aymanbagabas.go-udiff = "4ad777e23c62c40120812548719a9d734b9c39ac"
# github.com/charmbracelet/x/exp/golden@v0.0.0-20240815200342-61de596daa2b => 61de596daa2bf9171f8f9c20b0a537b42b38523e
SRCREV_github.com.charmbracelet.x.exp.golden = "61de596daa2bf9171f8f9c20b0a537b42b38523e"
# github.com/BurntSushi/toml@v1.4.0 => 1e2c053f442c0ac99df1f5b56bae3feab98caa4f
SRCREV_github.com.BurntSushi.toml = "1e2c053f442c0ac99df1f5b56bae3feab98caa4f"
# github.com/atotto/clipboard@v0.1.4 => e4aee1922c628e6966acd4207c408df132dc6fb5
SRCREV_github.com.atotto.clipboard = "e4aee1922c628e6966acd4207c408df132dc6fb5"
# github.com/sahilm/fuzzy@v0.1.1 => c48e322e2a8f19bbd962faf82eee4cf11dbf81ba
SRCREV_github.com.sahilm.fuzzy = "c48e322e2a8f19bbd962faf82eee4cf11dbf81ba"
# github.com/aymanbagabas/go-osc52/v2@v2.0.1 => ce73587a0f72cf077e55f163e71ea1b5496a133c
SRCREV_github.com.aymanbagabas.go-osc52.v2 = "ce73587a0f72cf077e55f163e71ea1b5496a133c"
# github.com/charmbracelet/bubbles@v0.20.0 => d3bd075ed2b27a3b5d76bb79b5d1c928dcd780d0
SRCREV_github.com.charmbracelet.bubbles = "d3bd075ed2b27a3b5d76bb79b5d1c928dcd780d0"
# github.com/charmbracelet/lipgloss@v1.0.0 => 761d265f761271293f20f9bf62884b15f2d7c0cc
SRCREV_github.com.charmbracelet.lipgloss = "761d265f761271293f20f9bf62884b15f2d7c0cc"
# github.com/charmbracelet/x/ansi@v0.4.5 => d3dd7340b31f6c8d8e95dc7ba55fccb38d6ba8ad
SRCREV_github.com.charmbracelet.x.ansi = "d3dd7340b31f6c8d8e95dc7ba55fccb38d6ba8ad"
# github.com/charmbracelet/x/term@v0.2.1 => 66d4aed428d9330a4b1a97b3d6fcd985b08cfaeb
SRCREV_github.com.charmbracelet.x.term = "66d4aed428d9330a4b1a97b3d6fcd985b08cfaeb"
# github.com/erikgeiser/coninput@v0.0.0-20211004153227-1c3628e74d0f => 1c3628e74d0f39ad7e963960ab9799c7f6ca3761
SRCREV_github.com.erikgeiser.coninput = "1c3628e74d0f39ad7e963960ab9799c7f6ca3761"
# github.com/lucasb-eyer/go-colorful@v1.2.0 => d2b05a0d83cca9d610425691c3253d5f36d0ad06
SRCREV_github.com.lucasb-eyer.go-colorful = "d2b05a0d83cca9d610425691c3253d5f36d0ad06"
# github.com/mattn/go-isatty@v0.0.20 => a7c02353c47bc4ec6b30dc9628154ae4fe760c11
SRCREV_github.com.mattn.go-isatty = "a7c02353c47bc4ec6b30dc9628154ae4fe760c11"
# github.com/mattn/go-localereader@v0.0.1 => 6338b4c69507fb1f9edba3db33882a8e9ab9bfa8
SRCREV_github.com.mattn.go-localereader = "6338b4c69507fb1f9edba3db33882a8e9ab9bfa8"
# github.com/mattn/go-runewidth@v0.0.16 => 6ceadc68530e7bfea8cba17d6523bed32912d4fa
SRCREV_github.com.mattn.go-runewidth = "6ceadc68530e7bfea8cba17d6523bed32912d4fa"
# github.com/muesli/ansi@v0.0.0-20230316100256-276c6243b2f6 => 276c6243b2f6df61db727937762b1a3f9cc12486
SRCREV_github.com.muesli.ansi = "276c6243b2f6df61db727937762b1a3f9cc12486"
# github.com/muesli/cancelreader@v0.2.2 => d11f1e77abf7f8d69d81553ccaaf0b81163541a6
SRCREV_github.com.muesli.cancelreader = "d11f1e77abf7f8d69d81553ccaaf0b81163541a6"
# github.com/muesli/termenv@v0.15.2 => 51d72d34e2b9778a31aa5dd79fbdd8cdac50b4d5
SRCREV_github.com.muesli.termenv = "51d72d34e2b9778a31aa5dd79fbdd8cdac50b4d5"
# github.com/rivo/uniseg@v0.4.7 => 03509a98a092b522b2ff0de13e53513d18b3b837
SRCREV_github.com.rivo.uniseg = "03509a98a092b522b2ff0de13e53513d18b3b837"
# golang.org/x/sync@v0.13.0 => 396f3a06ea2a49eb410f12e244c0dd77095d0de9
SRCREV_golang.org.x.sync = "396f3a06ea2a49eb410f12e244c0dd77095d0de9"
# golang.org/x/sys@v0.32.0 => 01aaa8342f9d6e36356d05d0baff28e64ee6367e
SRCREV_golang.org.x.sys = "01aaa8342f9d6e36356d05d0baff28e64ee6367e"
# golang.org/x/text@v0.24.0 => 4890c57b7721969ba8997aea0970c11004f1f5b7
SRCREV_golang.org.x.text = "4890c57b7721969ba8997aea0970c11004f1f5b7"

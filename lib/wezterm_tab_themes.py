"""Registry of 60 WezTerm Tab Bar Themes and Lua Generator.

Every single theme contains a dedicated 4-color palette, ensuring tabs 1, 2, 3, and 4
always present distinctive, vibrant, theme-tailored colors.

Covers:
1. Google & Material (1-10)
2. Powerline & Geometries (11-20)
3. Popular Dev Palettes (21-30)
4. Synth & Cyberpunk (31-40) [inspired by synth-shell-theme-picker]
5. Nature & Earth Palettes (41-50) [inspired by synth-shell-theme-picker]
6. Minimalist, Modern, Badges & CRT (51-60)
"""

import json
import math

THEMES = [   {   'bg_bar': '#15161c',
        'category': 'Google & Material',
        'description': 'Tons pastéis suaves (Azul, Vermelho, Verde, Amarelo) com texto de alto contraste.',
        'id': 1,
        'name': 'Google Soft Pastels',
        'palette': [   {'active_sym': '⚡ 🔵 ➜ ', 'bg': '#d0e1fd', 'fg': '#1a365d', 'inactive_sym': ' 🔘'},
                       {'active_sym': '⚡ 🔴 ➜ ', 'bg': '#fcd7d5', 'fg': '#5c1d1d', 'inactive_sym': ' 🔘'},
                       {'active_sym': '⚡ 🟢 ➜ ', 'bg': '#c6f6d5', 'fg': '#1c4532', 'inactive_sym': ' 🔘'},
                       {'active_sym': '⚡ 🟠 ➜ ', 'bg': '#fef3c7', 'fg': '#744210', 'inactive_sym': ' 🔘'}],
        'style': 'google_cycle',
        'use_fancy': True},
    {   'bg_bar': '#121318',
        'category': 'Google & Material',
        'description': 'Pílulas arredondadas nas 4 cores vibrantes do Google sobre barra grafite escura.',
        'id': 2,
        'name': 'Material You Floating Pills',
        'palette': [   {'active_sym': '⚡ 🔵 ➜ ', 'bg': '#4285F4', 'fg': '#ffffff', 'inactive_sym': ' 🔘'},
                       {'active_sym': '⚡ 🔴 ➜ ', 'bg': '#EA4335', 'fg': '#ffffff', 'inactive_sym': ' 🔘'},
                       {'active_sym': '⚡ 🟢 ➜ ', 'bg': '#34A853', 'fg': '#ffffff', 'inactive_sym': ' 🔘'},
                       {'active_sym': '⚡ 🟠 ➜ ', 'bg': '#FBBC05', 'fg': '#ffffff', 'inactive_sym': ' 🔘'}],
        'style': 'pills',
        'use_fancy': True},
    {   'bg_bar': '#1e1f26',
        'category': 'Google & Material',
        'description': 'Abas em ardósia moderna com pontos e destaques nas 4 cores do Google.',
        'id': 3,
        'name': 'Chrome Dark Modern',
        'palette': [   {'active_sym': '🔵 ➜ ', 'bg': '#2b3a55', 'fg': '#e2e8f0', 'inactive_sym': ' 🔵'},
                       {'active_sym': '🔴 ➜ ', 'bg': '#542d32', 'fg': '#fed7d7', 'inactive_sym': ' 🔴'},
                       {'active_sym': '🟢 ➜ ', 'bg': '#224b37', 'fg': '#c6f6d5', 'inactive_sym': ' 🟢'},
                       {'active_sym': '🟡 ➜ ', 'bg': '#544626', 'fg': '#fef3c7', 'inactive_sym': ' 🟡'}],
        'style': 'google_cycle',
        'use_fancy': True},
    {   'bg_bar': '#111217',
        'category': 'Google & Material',
        'description': 'Design escuro minimalista onde cada aba ostenta um ponto luminoso Google (🔵 🔴 🟢 🟡).',
        'id': 4,
        'name': 'Google Minimal Color Dots',
        'palette': [   {'active_sym': '● 🔵 ', 'bg': '#1e2230', 'fg': '#93c5fd', 'inactive_sym': ' 🔵'},
                       {'active_sym': '● 🔴 ', 'bg': '#2e1b1e', 'fg': '#fca5a5', 'inactive_sym': ' 🔴'},
                       {'active_sym': '● 🟢 ', 'bg': '#152e20', 'fg': '#86efac', 'inactive_sym': ' 🟢'},
                       {'active_sym': '● 🟡 ', 'bg': '#2e2915', 'fg': '#fde047', 'inactive_sym': ' 🟡'}],
        'style': 'google_cycle',
        'use_fancy': True},
    {   'bg_bar': '#16171d',
        'category': 'Google & Material',
        'description': 'Cor fixa por projeto: o nome do diretório escolhe a cor, então o mesmo projeto aparece sempre com a mesma cor, em qualquer aba.',
        'id': 5,
        'name': 'Google Project Colors',
        'palette': [   {'active_sym': '\U000f024b ', 'bg': '#1a73e8', 'fg': '#ffffff', 'inactive_sym': ''},
                       {'active_sym': '\U000f024b ', 'bg': '#d93025', 'fg': '#ffffff', 'inactive_sym': ''},
                       {'active_sym': '\U000f024b ', 'bg': '#188038', 'fg': '#ffffff', 'inactive_sym': ''},
                       {'active_sym': '\U000f024b ', 'bg': '#f9ab00', 'fg': '#202124', 'inactive_sym': ''},
                       {'active_sym': '\U000f024b ', 'bg': '#9334e6', 'fg': '#ffffff', 'inactive_sym': ''},
                       {'active_sym': '\U000f024b ', 'bg': '#12b5cb', 'fg': '#202124', 'inactive_sym': ''},
                       {'active_sym': '\U000f024b ', 'bg': '#e8710a', 'fg': '#202124', 'inactive_sym': ''},
                       {'active_sym': '\U000f024b ', 'bg': '#c51162', 'fg': '#ffffff', 'inactive_sym': ''}],
        'style': 'project_color',
        'use_fancy': True},
    {   'bg_bar': '#0f1117',
        'category': 'Google & Material',
        'description': 'Badges retangulares compactos nas cores do Google com cantos chanfrados.',
        'id': 6,
        'name': 'Google Badge Chips',
        'palette': [   {'active_sym': '\U000f02a2 ', 'bg': '#2563eb', 'fg': '#ffffff', 'inactive_sym': ' '},
                       {'active_sym': '\U000f0169 ', 'bg': '#dc2626', 'fg': '#ffffff', 'inactive_sym': ' '},
                       {'active_sym': '\U000f048b ', 'bg': '#16a34a', 'fg': '#ffffff', 'inactive_sym': ' '},
                       {'active_sym': '\ue73c ', 'bg': '#d97706', 'fg': '#ffffff', 'inactive_sym': ' '}],
        'style': 'pills',
        'use_fancy': True},
    {   'bg_bar': '#13161f',
        'alert_color': '#fdd663',
        'category': 'Google & Material',
        'description': 'Mostra ● nas abas com saída nova que você ainda não viu e ⏳ enquanto um comando roda — ideal para acompanhar jobs longos.',
        'id': 7,
        'name': 'Google Activity Radar',
        'palette': [   {'active_sym': '⚡ ', 'bg': '#174ea6', 'fg': '#ffffff', 'inactive_sym': ''},
                       {'active_sym': '⚡ ', 'bg': '#a50e0e', 'fg': '#ffffff', 'inactive_sym': ''},
                       {'active_sym': '⚡ ', 'bg': '#0d652d', 'fg': '#ffffff', 'inactive_sym': ''},
                       {'active_sym': '⚡ ', 'bg': '#8d4e00', 'fg': '#ffffff', 'inactive_sym': ''}],
        'style': 'activity',
        'use_fancy': True},
    {   'bg_bar': '#202124',
        'category': 'Google & Material',
        'description': 'Abas inativas em grafite discreto, só com o número na cor da aba; apenas a aba ativa ganha cor — visual calmo, sem arco-íris.',
        'id': 8,
        'muted_bg': '#303134',
        'muted_fg': '#9aa0a6',
        'name': 'Material Mono Accent',
        'palette': [   {'active_sym': '● ', 'bg': '#8ab4f8', 'fg': '#202124', 'inactive_sym': ''},
                       {'active_sym': '● ', 'bg': '#f28b82', 'fg': '#202124', 'inactive_sym': ''},
                       {'active_sym': '● ', 'bg': '#81c995', 'fg': '#202124', 'inactive_sym': ''},
                       {'active_sym': '● ', 'bg': '#fdd663', 'fg': '#202124', 'inactive_sym': ''}],
        'style': 'mono_accent',
        'use_fancy': True},
    {   'bg_bar': '#1b1b1f',
        'category': 'Google & Material',
        'description': 'Paleta de extração dinâmica Monet do Android 14 com tons pastéis orgânicos e harmônicos.',
        'id': 9,
        'name': 'Google Android 14 Monet',
        'palette': [   {'active_sym': '⚡ ➜ ', 'bg': '#b4c5ff', 'fg': '#1b3060', 'inactive_sym': ' ·'},
                       {'active_sym': '⚡ ➜ ', 'bg': '#ffb3b8', 'fg': '#60121e', 'inactive_sym': ' ·'},
                       {'active_sym': '⚡ ➜ ', 'bg': '#b6d1b7', 'fg': '#1b3720', 'inactive_sym': ' ·'},
                       {'active_sym': '⚡ ➜ ', 'bg': '#f0e1a1', 'fg': '#3e3000', 'inactive_sym': ' ·'}],
        'style': 'google_cycle',
        'use_fancy': True},
    {   'bg_bar': '#0b1220',
        'category': 'Google & Material',
        'description': 'Quatro tons do azul Google, do mais escuro ao mais claro — um tema de cor única, sem o arco-íris de sempre.',
        'id': 10,
        'name': 'Google Blue Gradient',
        'palette': [   {'active_sym': '❯ ', 'bg': '#0842a0', 'fg': '#ffffff', 'inactive_sym': ' ·'},
                       {'active_sym': '❯ ', 'bg': '#0b57d0', 'fg': '#ffffff', 'inactive_sym': ' ·'},
                       {'active_sym': '❯ ', 'bg': '#4c8df6', 'fg': '#041e49', 'inactive_sym': ' ·'},
                       {'active_sym': '❯ ', 'bg': '#a8c7fa', 'fg': '#041e49', 'inactive_sym': ' ·'}],
        'style': 'pills',
        'use_fancy': True},
    {   'bg_bar': '#0f172a',
        'category': 'Powerline & Geometrias',
        'description': 'Setas Powerline tradicionais conectando 4 abas em Azul, Roxo, Esmeralda e Âmbar.',
        'id': 11,
        'name': 'Classic Powerline Arrow',
        'palette': [   {'active_sym': '⚡ ➜ ', 'bg': '#2563eb', 'fg': '#ffffff', 'inactive_sym': '  '},
                       {'active_sym': '⚡ ➜ ', 'bg': '#7c3aed', 'fg': '#ffffff', 'inactive_sym': '  '},
                       {'active_sym': '⚡ ➜ ', 'bg': '#059669', 'fg': '#ffffff', 'inactive_sym': '  '},
                       {'active_sym': '⚡ ➜ ', 'bg': '#d97706', 'fg': '#ffffff', 'inactive_sym': '  '}],
        'powerline_type': 'arrow',
        'sep_char': '\ue0b0',
        'sep_thin': '\ue0b1',
        'style': 'powerline',
        'use_fancy': False},
    {   'bg_bar': '#0d1117',
        'category': 'Powerline & Geometrias',
        'description': 'Bordas em cápsula arredondada (bubbles) com transições suaves e cores modernas.',
        'id': 12,
        'name': 'Rounded Bubble Powerline',
        'palette': [   {'active_sym': '⚡ ', 'bg': '#0284c7', 'fg': '#ffffff', 'inactive_sym': ' '},
                       {'active_sym': '⚡ ', 'bg': '#8b5cf6', 'fg': '#ffffff', 'inactive_sym': ' '},
                       {'active_sym': '⚡ ', 'bg': '#10b981', 'fg': '#ffffff', 'inactive_sym': ' '},
                       {'active_sym': '⚡ ', 'bg': '#f43f5e', 'fg': '#ffffff', 'inactive_sym': ' '}],
        'powerline_type': 'bubble',
        'sep_char': '\ue0b4',
        'sep_left': '\ue0b6',
        'style': 'powerline',
        'use_fancy': False},
    {   'bg_bar': '#14141e',
        'category': 'Powerline & Geometrias',
        'description': 'Corte diagonal agressivo com gradiente de tons em anil, ciano, verde-limão e rubi.',
        'id': 13,
        'name': 'Slanted Diagonal Cut',
        'palette': [   {'active_sym': '⚡ ', 'bg': '#4338ca', 'fg': '#ffffff', 'inactive_sym': ' '},
                       {'active_sym': '⚡ ', 'bg': '#0891b2', 'fg': '#ffffff', 'inactive_sym': ' '},
                       {'active_sym': '⚡ ', 'bg': '#65a30d', 'fg': '#ffffff', 'inactive_sym': ' '},
                       {'active_sym': '⚡ ', 'bg': '#e11d48', 'fg': '#ffffff', 'inactive_sym': ' '}],
        'powerline_type': 'slant',
        'sep_char': '\ue0bc',
        'style': 'powerline',
        'use_fancy': False},
    {   'bg_bar': '#180a0a',
        'category': 'Powerline & Geometrias',
        'description': 'Chamas vívidas em degradê térmico: Vermelho Incandescente, Laranja Fogo, Ouro e Carmesim.',
        'id': 14,
        'name': 'Flame Cyber Spikes',
        'palette': [   {'active_sym': '🔥 ', 'bg': '#dc2626', 'fg': '#ffffff', 'inactive_sym': ' '},
                       {'active_sym': '🔥 ', 'bg': '#ea580c', 'fg': '#ffffff', 'inactive_sym': ' '},
                       {'active_sym': '🔥 ', 'bg': '#ca8a04', 'fg': '#ffffff', 'inactive_sym': ' '},
                       {'active_sym': '🔥 ', 'bg': '#991b1b', 'fg': '#ffffff', 'inactive_sym': ' '}],
        'powerline_type': 'arrow',
        'sep_char': '\ue0b0',
        'style': 'powerline',
        'use_fancy': False},
    {   'bg_bar': '#181b22',
        'category': 'Powerline & Geometrias',
        'description': 'Divisores sutis chevron em estilo limpo, profissional e moderno.',
        'id': 15,
        'name': 'Thin Chevron Dividers',
        'palette': [   {'active_sym': '❯ ', 'bg': '#334155', 'fg': '#f1f5f9', 'inactive_sym': '  '},
                       {'active_sym': '❯ ', 'bg': '#1e3a4a', 'fg': '#e2e8f0', 'inactive_sym': '  '},
                       {'active_sym': '❯ ', 'bg': '#1e382b', 'fg': '#e2e8f0', 'inactive_sym': '  '},
                       {'active_sym': '❯ ', 'bg': '#3b351e', 'fg': '#e2e8f0', 'inactive_sym': '  '}],
        'powerline_type': 'chevron',
        'sep_char': '\ue0b1',
        'style': 'powerline',
        'use_fancy': False},
    {   'bg_bar': '#19160e',
        'category': 'Powerline & Geometrias',
        'description': 'Geometrias hexagonais e tons de mel, âmbar dourado e oliva aquecido.',
        'id': 16,
        'name': 'Hexagon Honeycomb Lego',
        'palette': [   {'active_sym': '⬡ ', 'bg': '#f59e0b', 'fg': '#ffffff', 'inactive_sym': ' '},
                       {'active_sym': '⬡ ', 'bg': '#d97706', 'fg': '#ffffff', 'inactive_sym': ' '},
                       {'active_sym': '⬡ ', 'bg': '#84cc16', 'fg': '#ffffff', 'inactive_sym': ' '},
                       {'active_sym': '⬡ ', 'bg': '#b45309', 'fg': '#ffffff', 'inactive_sym': ' '}],
        'powerline_type': 'hexagon',
        'sep_char': '\ue0b0',
        'style': 'powerline',
        'use_fancy': False},
    {   'bg_bar': '#0b1520',
        'category': 'Powerline & Geometrias',
        'description': 'Ondulação marinha suave conectando ciano profundo, azul oceano, azul royal e coral.',
        'id': 17,
        'name': 'Sine Wave S-Curve',
        'palette': [   {'active_sym': '〰 ', 'bg': '#06b6d4', 'fg': '#ffffff', 'inactive_sym': ' '},
                       {'active_sym': '〰 ', 'bg': '#0ea5e9', 'fg': '#ffffff', 'inactive_sym': ' '},
                       {'active_sym': '〰 ', 'bg': '#3b82f6', 'fg': '#ffffff', 'inactive_sym': ' '},
                       {'active_sym': '〰 ', 'bg': '#f43f5e', 'fg': '#ffffff', 'inactive_sym': ' '}],
        'powerline_type': 'arrow',
        'sep_char': '\ue0b0',
        'style': 'powerline',
        'use_fancy': False},
    {   'bg_bar': '#0f1722',
        'category': 'Powerline & Geometrias',
        'description': 'Ângulos em trapézio com paleta polar: Ciano Glacial, Índigo, Menta Ártica e Safira.',
        'id': 18,
        'name': 'Trapezoid Notch Ice',
        'palette': [   {'active_sym': '▲ ', 'bg': '#38bdf8', 'fg': '#0f172a', 'inactive_sym': ' '},
                       {'active_sym': '▲ ', 'bg': '#6366f1', 'fg': '#ffffff', 'inactive_sym': ' '},
                       {'active_sym': '▲ ', 'bg': '#2dd4bf', 'fg': '#0f172a', 'inactive_sym': ' '},
                       {'active_sym': '▲ ', 'bg': '#0284c7', 'fg': '#ffffff', 'inactive_sym': ' '}],
        'powerline_type': 'arrow',
        'sep_char': '\ue0b0',
        'style': 'powerline',
        'use_fancy': False},
    {   'bg_bar': '#0e0e16',
        'category': 'Powerline & Geometrias',
        'description': 'Estilo arcade pixelado com 4 cores vibrantes estilo fliperama retrô.',
        'id': 19,
        'name': 'Pixel 8-Bit Retro',
        'palette': [   {'active_sym': '👾 ', 'bg': '#00e5ff', 'fg': '#101018', 'inactive_sym': ' '},
                       {'active_sym': '👾 ', 'bg': '#ff007f', 'fg': '#ffffff', 'inactive_sym': ' '},
                       {'active_sym': '👾 ', 'bg': '#00e676', 'fg': '#101018', 'inactive_sym': ' '},
                       {'active_sym': '👾 ', 'bg': '#ffd600', 'fg': '#101018', 'inactive_sym': ' '}],
        'powerline_type': 'arrow',
        'sep_char': '\ue0b0',
        'style': 'powerline',
        'use_fancy': False},
    {   'bg_bar': '#151722',
        'category': 'Powerline & Geometrias',
        'description': 'Recorte inclinado a 45 graus com Azul Elétrico, Magenta Neon, Verde Neon e Laranja Solar.',
        'id': 20,
        'name': 'Diagonal Slash 45°',
        'palette': [   {'active_sym': '⚡ ', 'bg': '#3b82f6', 'fg': '#ffffff', 'inactive_sym': ' '},
                       {'active_sym': '⚡ ', 'bg': '#d946ef', 'fg': '#ffffff', 'inactive_sym': ' '},
                       {'active_sym': '⚡ ', 'bg': '#22c55e', 'fg': '#ffffff', 'inactive_sym': ' '},
                       {'active_sym': '⚡ ', 'bg': '#f97316', 'fg': '#ffffff', 'inactive_sym': ' '}],
        'powerline_type': 'slant',
        'sep_char': '\ue0bc',
        'style': 'powerline',
        'use_fancy': False},
    {   'bg_bar': '#1a1a1a',
        'category': 'Paletas Populares Devs',
        'description': 'Cores lendárias do Monokai Pro: Rosa Magenta, Azul Ciano, Amarelo e Verde Limão.',
        'id': 21,
        'name': 'Monokai Vivid Match',
        'palette': [   {'active_sym': '⚡ ➜ ', 'bg': '#f92672', 'fg': '#ffffff', 'inactive_sym': ' 🔘'},
                       {'active_sym': '⚡ ➜ ', 'bg': '#66d9ef', 'fg': '#272822', 'inactive_sym': ' 🔘'},
                       {'active_sym': '⚡ ➜ ', 'bg': '#e6db74', 'fg': '#272822', 'inactive_sym': ' 🔘'},
                       {'active_sym': '⚡ ➜ ', 'bg': '#a6e22e', 'fg': '#272822', 'inactive_sym': ' 🔘'}],
        'style': 'palette_cycle',
        'use_fancy': True},
    {   'bg_bar': '#11111b',
        'category': 'Paletas Populares Devs',
        'description': 'Tons pastéis aconchegantes do Catppuccin: Mauve (Roxo), Safira, Verde e Pêssego.',
        'id': 22,
        'name': 'Catppuccin Mocha',
        'palette': [   {'active_sym': '\U000f011b ➜ ', 'bg': '#cba6f7', 'fg': '#11111b', 'inactive_sym': ' \U000f011b'},
                       {'active_sym': '\U000f011b ➜ ', 'bg': '#74c7ec', 'fg': '#11111b', 'inactive_sym': ' \U000f011b'},
                       {'active_sym': '\U000f011b ➜ ', 'bg': '#a6e3a1', 'fg': '#11111b', 'inactive_sym': ' \U000f011b'},
                       {   'active_sym': '\U000f011b ➜ ',
                           'bg': '#fab387',
                           'fg': '#11111b',
                           'inactive_sym': ' \U000f011b'}],
        'style': 'palette_cycle',
        'use_fancy': True},
    {   'bg_bar': '#16161e',
        'category': 'Paletas Populares Devs',
        'description': 'Luzes noturnas de Shibuya: Ciano Tempestade, Púrpura, Verde Tóquio e Laranja Sol.',
        'id': 23,
        'name': 'Tokyo Night Storm',
        'palette': [   {'active_sym': '⚡ ➜ ', 'bg': '#7dcfff', 'fg': '#1a1b26', 'inactive_sym': ' 🔘'},
                       {'active_sym': '⚡ ➜ ', 'bg': '#bb9af7', 'fg': '#1a1b26', 'inactive_sym': ' 🔘'},
                       {'active_sym': '⚡ ➜ ', 'bg': '#9ece6a', 'fg': '#1a1b26', 'inactive_sym': ' 🔘'},
                       {'active_sym': '⚡ ➜ ', 'bg': '#ff9e64', 'fg': '#1a1b26', 'inactive_sym': ' 🔘'}],
        'style': 'pills',
        'use_fancy': True},
    {   'bg_bar': '#242933',
        'category': 'Paletas Populares Devs',
        'description': 'Gelo polar ártico: Azul Frost, Azul Polar Claro, Aurora Verde e Aurora Dourada.',
        'id': 24,
        'name': 'Nord Frost Arctic',
        'palette': [   {'active_sym': '❄ ➜ ', 'bg': '#88c0d0', 'fg': '#2e3440', 'inactive_sym': ' ❄'},
                       {'active_sym': '❄ ➜ ', 'bg': '#81a1c1', 'fg': '#2e3440', 'inactive_sym': ' ❄'},
                       {'active_sym': '❄ ➜ ', 'bg': '#a3be8c', 'fg': '#2e3440', 'inactive_sym': ' ❄'},
                       {'active_sym': '❄ ➜ ', 'bg': '#ebcb8b', 'fg': '#2e3440', 'inactive_sym': ' ❄'}],
        'style': 'pills',
        'use_fancy': True},
    {   'bg_bar': '#1e1f29',
        'category': 'Paletas Populares Devs',
        'description': 'Contraste gótico eletrizante: Rosa Punch, Roxo Drácula, Verde Néon e Ciano Brilhante.',
        'id': 25,
        'name': 'Dracula Punch',
        'palette': [   {'active_sym': '⚡ 🦇 ➜ ', 'bg': '#ff79c6', 'fg': '#282a36', 'inactive_sym': ' 🦇'},
                       {'active_sym': '⚡ 🦇 ➜ ', 'bg': '#bd93f9', 'fg': '#282a36', 'inactive_sym': ' 🦇'},
                       {'active_sym': '⚡ 🦇 ➜ ', 'bg': '#50fa7b', 'fg': '#282a36', 'inactive_sym': ' 🦇'},
                       {'active_sym': '⚡ 🦇 ➜ ', 'bg': '#8be9fd', 'fg': '#282a36', 'inactive_sym': ' 🦇'}],
        'style': 'pills',
        'use_fancy': True},
    {   'bg_bar': '#1d2021',
        'category': 'Paletas Populares Devs',
        'description': 'Calor retrô inconfundível do Gruvbox: Aqua Claro, Verde Musgo, Amarelo Ouro e Laranja Âmbar.',
        'id': 26,
        'name': 'Gruvbox Dark Warm',
        'palette': [   {'active_sym': '● ➜ ', 'bg': '#8ec07c', 'fg': '#282828', 'inactive_sym': ' ○'},
                       {'active_sym': '● ➜ ', 'bg': '#b8bb26', 'fg': '#282828', 'inactive_sym': ' ○'},
                       {'active_sym': '● ➜ ', 'bg': '#fabd2f', 'fg': '#282828', 'inactive_sym': ' ○'},
                       {'active_sym': '● ➜ ', 'bg': '#fe8019', 'fg': '#282828', 'inactive_sym': ' ○'}],
        'style': 'pills',
        'use_fancy': True},
    {   'bg_bar': '#1e2227',
        'category': 'Paletas Populares Devs',
        'description': 'Design clássico do editor Atom: Azul Claro, Roxo Suave, Verde Menta e Coral Salmão.',
        'id': 27,
        'name': 'One Dark Pro Atom',
        'palette': [   {'active_sym': '⚡ ➜ ', 'bg': '#61afef', 'fg': '#21252b', 'inactive_sym': ' 🔘'},
                       {'active_sym': '⚡ ➜ ', 'bg': '#c678dd', 'fg': '#21252b', 'inactive_sym': ' 🔘'},
                       {'active_sym': '⚡ ➜ ', 'bg': '#98c379', 'fg': '#21252b', 'inactive_sym': ' 🔘'},
                       {'active_sym': '⚡ ➜ ', 'bg': '#e06c75', 'fg': '#21252b', 'inactive_sym': ' 🔘'}],
        'style': 'pills',
        'use_fancy': True},
    {   'bg_bar': '#191724',
        'category': 'Paletas Populares Devs',
        'description': 'Estética relaxante do Rosé Pine: Rosa Pétala, Íris Violeta, Espuma do Mar e Ouro Antigo.',
        'id': 28,
        'name': 'Rosé Pine Moon',
        'palette': [   {'active_sym': '🌸 ➜ ', 'bg': '#ebbcba', 'fg': '#191724', 'inactive_sym': ' 🌸'},
                       {'active_sym': '🌸 ➜ ', 'bg': '#c4a7e7', 'fg': '#191724', 'inactive_sym': ' 🌸'},
                       {'active_sym': '🌸 ➜ ', 'bg': '#9ccfd8', 'fg': '#191724', 'inactive_sym': ' 🌸'},
                       {'active_sym': '🌸 ➜ ', 'bg': '#f6c177', 'fg': '#191724', 'inactive_sym': ' 🌸'}],
        'style': 'pills',
        'use_fancy': True},
    {   'bg_bar': '#1c2128',
        'category': 'Paletas Populares Devs',
        'description': 'Paleta oficial do GitHub: Azul Octocat, Roxo Pull-Request, Verde Commit e Laranja Issue.',
        'id': 29,
        'name': 'GitHub Dark Dimmed',
        'palette': [   {'active_sym': '\U000f02a4 ➜ ', 'bg': '#539bf5', 'fg': '#22272e', 'inactive_sym': ' \U000f02a4'},
                       {'active_sym': '\U000f02a4 ➜ ', 'bg': '#b392f0', 'fg': '#22272e', 'inactive_sym': ' \U000f02a4'},
                       {'active_sym': '\U000f02a4 ➜ ', 'bg': '#57ab5f', 'fg': '#22272e', 'inactive_sym': ' \U000f02a4'},
                       {   'active_sym': '\U000f02a4 ➜ ',
                           'bg': '#f0883e',
                           'fg': '#22272e',
                           'inactive_sym': ' \U000f02a4'}],
        'style': 'pills',
        'use_fancy': True},
    {   'bg_bar': '#181818',
        'category': 'Paletas Populares Devs',
        'description': 'Identidade visual do VS Code: Azul Oficial, Violeta Type, Ciano Keyword e Laranja String.',
        'id': 30,
        'name': 'VS Code Modern Dark',
        'palette': [   {'active_sym': '\U000f0a1e ➜ ', 'bg': '#007acc', 'fg': '#ffffff', 'inactive_sym': ' \U000f0a1e'},
                       {'active_sym': '\U000f0a1e ➜ ', 'bg': '#af7ac5', 'fg': '#ffffff', 'inactive_sym': ' \U000f0a1e'},
                       {'active_sym': '\U000f0a1e ➜ ', 'bg': '#4ec9b0', 'fg': '#181818', 'inactive_sym': ' \U000f0a1e'},
                       {   'active_sym': '\U000f0a1e ➜ ',
                           'bg': '#ce9178',
                           'fg': '#181818',
                           'inactive_sym': ' \U000f0a1e'}],
        'style': 'pills',
        'use_fancy': True},
    {   'bg_bar': '#0a0a0c',
        'category': 'Synth & Cyberpunk',
        'description': 'Night City visceral: Amarelo Chooh2, Ciano Implante, Magenta Neon e Verde Matrix.',
        'id': 31,
        'name': 'Cyberpunk Edgerunners',
        'palette': [   {'active_sym': '⚡ ⬡ ➜ ', 'bg': '#fcee0a', 'fg': '#0a0a0c', 'inactive_sym': ' ⬡'},
                       {'active_sym': '⚡ ⬡ ➜ ', 'bg': '#00f0ff', 'fg': '#0a0a0c', 'inactive_sym': ' ⬡'},
                       {'active_sym': '⚡ ⬡ ➜ ', 'bg': '#ff003c', 'fg': '#ffffff', 'inactive_sym': ' ⬡'},
                       {'active_sym': '⚡ ⬡ ➜ ', 'bg': '#00ff66', 'fg': '#0a0a0c', 'inactive_sym': ' ⬡'}],
        'style': 'pills',
        'use_fancy': True},
    {   'bg_bar': '#100c1e',
        'category': 'Synth & Cyberpunk',
        'description': 'Pôr do sol em Miami: Ciano Pastel, Rosa Choque, Púrpura Neon e Pêssego Solar.',
        'id': 32,
        'name': 'Miami Vice 80s',
        'palette': [   {'active_sym': '🌴 ➜ ', 'bg': '#00f5d4', 'fg': '#100c1e', 'inactive_sym': ' 🌴'},
                       {'active_sym': '🌴 ➜ ', 'bg': '#ff6b9d', 'fg': '#100c1e', 'inactive_sym': ' 🌴'},
                       {'active_sym': '🌴 ➜ ', 'bg': '#9d4edd', 'fg': '#ffffff', 'inactive_sym': ' 🌴'},
                       {'active_sym': '🌴 ➜ ', 'bg': '#ffbe0b', 'fg': '#100c1e', 'inactive_sym': ' 🌴'}],
        'style': 'palette_cycle',
        'use_fancy': True},
    {   'bg_bar': '#0e0717',
        'category': 'Synth & Cyberpunk',
        'description': 'Inspirado no EVA-01: Roxo Berserk, Verde Tóxico, Laranja Nerv e Ciano Rei.',
        'id': 33,
        'name': 'Neon Genesis Evangelion',
        'palette': [   {'active_sym': '▲ ➜ ', 'bg': '#7b2cbf', 'fg': '#ffffff', 'inactive_sym': ' △'},
                       {'active_sym': '▲ ➜ ', 'bg': '#39ff14', 'fg': '#0e0717', 'inactive_sym': ' △'},
                       {'active_sym': '▲ ➜ ', 'bg': '#ff6b35', 'fg': '#ffffff', 'inactive_sym': ' △'},
                       {'active_sym': '▲ ➜ ', 'bg': '#00d2d3', 'fg': '#0e0717', 'inactive_sym': ' △'}],
        'style': 'pills',
        'use_fancy': True},
    {   'bg_bar': '#120826',
        'category': 'Synth & Cyberpunk',
        'description': 'Radiação anos 80: Magenta Incandescente, Azul Laser, Verde Fosforescente e Violeta.',
        'id': 34,
        'name': 'Synthwave Pink Glow',
        'palette': [   {'active_sym': '⚡ ➜ ', 'bg': '#ff71ce', 'fg': '#120826', 'inactive_sym': ' 🔘'},
                       {'active_sym': '⚡ ➜ ', 'bg': '#01cdfe', 'fg': '#120826', 'inactive_sym': ' 🔘'},
                       {'active_sym': '⚡ ➜ ', 'bg': '#05ffa1', 'fg': '#120826', 'inactive_sym': ' 🔘'},
                       {'active_sym': '⚡ ➜ ', 'bg': '#b967ff', 'fg': '#ffffff', 'inactive_sym': ' 🔘'}],
        'style': 'pills',
        'use_fancy': True},
    {   'bg_bar': '#16161e',
        'category': 'Synth & Cyberpunk',
        'description': 'Horizonte synthwave: Framboesa Escuro, Coral Quente, Lavanda e Menta Suave.',
        'id': 35,
        'name': 'Horizon Synth',
        'palette': [   {'active_sym': '🌇 ➜ ', 'bg': '#e95678', 'fg': '#ffffff', 'inactive_sym': ' 🌇'},
                       {'active_sym': '🌇 ➜ ', 'bg': '#fab795', 'fg': '#16161e', 'inactive_sym': ' 🌇'},
                       {'active_sym': '🌇 ➜ ', 'bg': '#b877db', 'fg': '#ffffff', 'inactive_sym': ' 🌇'},
                       {'active_sym': '🌇 ➜ ', 'bg': '#25b0bc', 'fg': '#ffffff', 'inactive_sym': ' 🌇'}],
        'style': 'palette_cycle',
        'use_fancy': True},
    {   'bg_bar': '#0d0f18',
        'category': 'Synth & Cyberpunk',
        'description': 'Chuva digital futurista: Verde Terminal, Ciano Cibernético, Roxo Cyber e Ouro Holográfico.',
        'id': 36,
        'name': 'Cyberdream Matrix',
        'palette': [   {'active_sym': '⚡ ➜ ', 'bg': '#5eff6c', 'fg': '#0d0f18', 'inactive_sym': ' 🔘'},
                       {'active_sym': '⚡ ➜ ', 'bg': '#5ef1ff', 'fg': '#0d0f18', 'inactive_sym': ' 🔘'},
                       {'active_sym': '⚡ ➜ ', 'bg': '#bd5eff', 'fg': '#ffffff', 'inactive_sym': ' 🔘'},
                       {'active_sym': '⚡ ➜ ', 'bg': '#ffbd5e', 'fg': '#0d0f18', 'inactive_sym': ' 🔘'}],
        'style': 'pills',
        'use_fancy': True},
    {   'bg_bar': '#100d1c',
        'category': 'Synth & Cyberpunk',
        'description': 'Nébula intergaláctica: Magenta Cósmico, Ciano Estelar, Laranja Supernova e Verde Aurora.',
        'id': 37,
        'name': 'Andromeda Galaxy',
        'palette': [   {'active_sym': '✨ ➜ ', 'bg': '#c74ded', 'fg': '#ffffff', 'inactive_sym': ' ✨'},
                       {'active_sym': '✨ ➜ ', 'bg': '#00e8c6', 'fg': '#100d1c', 'inactive_sym': ' ✨'},
                       {'active_sym': '✨ ➜ ', 'bg': '#ff8359', 'fg': '#ffffff', 'inactive_sym': ' ✨'},
                       {'active_sym': '✨ ➜ ', 'bg': '#9be564', 'fg': '#100d1c', 'inactive_sym': ' ✨'}],
        'style': 'pills',
        'use_fancy': True},
    {   'bg_bar': '#120d20',
        'category': 'Synth & Cyberpunk',
        'description': 'Cristais noturnos: Ametista Real, Lavanda Iluminada, Azul Topázio e Quartzo Rosa.',
        'id': 38,
        'name': 'Midnight Amethyst',
        'palette': [   {'active_sym': '💎 ➜ ', 'bg': '#9d4edd', 'fg': '#ffffff', 'inactive_sym': ' 💎'},
                       {'active_sym': '💎 ➜ ', 'bg': '#c77dff', 'fg': '#120d20', 'inactive_sym': ' 💎'},
                       {'active_sym': '💎 ➜ ', 'bg': '#70d6ff', 'fg': '#120d20', 'inactive_sym': ' 💎'},
                       {'active_sym': '💎 ➜ ', 'bg': '#ff70a6', 'fg': '#ffffff', 'inactive_sym': ' 💎'}],
        'style': 'pills',
        'use_fancy': True},
    {   'bg_bar': '#150e24',
        'category': 'Synth & Cyberpunk',
        'description': 'Aesthetic nostálgico: Rosa Choque, Violeta Profundo, Menta Água e Azul Bebê.',
        'id': 39,
        'name': 'Vaporwave Sunset',
        'palette': [   {'active_sym': '📼 ➜ ', 'bg': '#f72585', 'fg': '#ffffff', 'inactive_sym': ' 📼'},
                       {'active_sym': '📼 ➜ ', 'bg': '#7209b7', 'fg': '#ffffff', 'inactive_sym': ' 📼'},
                       {'active_sym': '📼 ➜ ', 'bg': '#4cc9f0', 'fg': '#150e24', 'inactive_sym': ' 📼'},
                       {'active_sym': '📼 ➜ ', 'bg': '#4895ef', 'fg': '#ffffff', 'inactive_sym': ' 📼'}],
        'style': 'palette_cycle',
        'use_fancy': True},
    {   'bg_bar': '#08141d',
        'category': 'Synth & Cyberpunk',
        'description': 'Criaturas abissais luminosas: Aqua Fósforo, Rosa Medusa, Ciano Profundo e Verde Neon.',
        'id': 40,
        'name': 'Bioluminescence Deep',
        'palette': [   {'active_sym': '🌊 ➜ ', 'bg': '#00f5d4', 'fg': '#08141d', 'inactive_sym': ' 🌊'},
                       {'active_sym': '🌊 ➜ ', 'bg': '#f72585', 'fg': '#ffffff', 'inactive_sym': ' 🌊'},
                       {'active_sym': '🌊 ➜ ', 'bg': '#48cae4', 'fg': '#08141d', 'inactive_sym': ' 🌊'},
                       {'active_sym': '🌊 ➜ ', 'bg': '#70e000', 'fg': '#08141d', 'inactive_sym': ' 🌊'}],
        'style': 'pills',
        'use_fancy': True},
    {   'bg_bar': '#1e2326',
        'category': 'Natureza & Tons Terrosos',
        'description': 'Bosque místico equilibrado: Verde Floresta, Sálvia Brilhante, Areia Dourada e Terracota.',
        'id': 41,
        'name': 'Everforest Dark',
        'palette': [   {'active_sym': '🌲 ➜ ', 'bg': '#a7c080', 'fg': '#1e2326', 'inactive_sym': ' 🌲'},
                       {'active_sym': '🌲 ➜ ', 'bg': '#83c092', 'fg': '#1e2326', 'inactive_sym': ' 🌲'},
                       {'active_sym': '🌲 ➜ ', 'bg': '#dbbc7f', 'fg': '#1e2326', 'inactive_sym': ' 🌲'},
                       {'active_sym': '🌲 ➜ ', 'bg': '#e67e80', 'fg': '#1e2326', 'inactive_sym': ' 🌲'}],
        'style': 'pills',
        'use_fancy': True},
    {   'bg_bar': '#181820',
        'category': 'Natureza & Tons Terrosos',
        'description': 'A Grande Onda de Hokusai: Azul Onda, Verde Primavera, Amarelo Carpa e Rosa Flor de Cerejeira.',
        'id': 42,
        'name': 'Kanagawa Wave',
        'palette': [   {'active_sym': '🌊 ➜ ', 'bg': '#7e9cd8', 'fg': '#181820', 'inactive_sym': ' 🌊'},
                       {'active_sym': '🌊 ➜ ', 'bg': '#98bb6c', 'fg': '#181820', 'inactive_sym': ' 🌊'},
                       {'active_sym': '🌊 ➜ ', 'bg': '#e6c384', 'fg': '#181820', 'inactive_sym': ' 🌊'},
                       {'active_sym': '🌊 ➜ ', 'bg': '#d27e99', 'fg': '#181820', 'inactive_sym': ' 🌊'}],
        'style': 'pills',
        'use_fancy': True},
    {   'bg_bar': '#1f181d',
        'category': 'Natureza & Tons Terrosos',
        'description': 'Primavera no Japão: Rosa Pétala, Coral Cerejeira, Verde Folha e Menta Manhã.',
        'id': 43,
        'name': 'Sakura Blossom',
        'palette': [   {'active_sym': '🌸 ➜ ', 'bg': '#ff758f', 'fg': '#ffffff', 'inactive_sym': ' 🌸'},
                       {'active_sym': '🌸 ➜ ', 'bg': '#ff4d6d', 'fg': '#ffffff', 'inactive_sym': ' 🌸'},
                       {'active_sym': '🌸 ➜ ', 'bg': '#a3c9a8', 'fg': '#1f181d', 'inactive_sym': ' 🌸'},
                       {'active_sym': '🌸 ➜ ', 'bg': '#84dcc6', 'fg': '#1f181d', 'inactive_sym': ' 🌸'}],
        'style': 'pills',
        'use_fancy': True},
    {   'bg_bar': '#191d17',
        'category': 'Natureza & Tons Terrosos',
        'description': 'Café artesanal: Verde Matcha Intenso, Espuma Creme, Sálvia e Caramelo Quente.',
        'id': 44,
        'name': 'Matcha Cream Latte',
        'palette': [   {'active_sym': '🍵 ➜ ', 'bg': '#588157', 'fg': '#ffffff', 'inactive_sym': ' 🍵'},
                       {'active_sym': '🍵 ➜ ', 'bg': '#a3b18a', 'fg': '#191d17', 'inactive_sym': ' 🍵'},
                       {'active_sym': '🍵 ➜ ', 'bg': '#3a5a40', 'fg': '#ffffff', 'inactive_sym': ' 🍵'},
                       {'active_sym': '🍵 ➜ ', 'bg': '#dda15e', 'fg': '#191d17', 'inactive_sym': ' 🍵'}],
        'style': 'pills',
        'use_fancy': True},
    {   'bg_bar': '#1e1814',
        'category': 'Natureza & Tons Terrosos',
        'description': 'Deserto ao entardecer: Terracota Âmbar, Dunas Douradas, Ocre Solar e Verde Oásis.',
        'id': 45,
        'name': 'Desert Dunes',
        'palette': [   {'active_sym': '🏜 ➜ ', 'bg': '#e76f51', 'fg': '#ffffff', 'inactive_sym': ' 🏜'},
                       {'active_sym': '🏜 ➜ ', 'bg': '#f4a261', 'fg': '#1e1814', 'inactive_sym': ' 🏜'},
                       {'active_sym': '🏜 ➜ ', 'bg': '#e9c46a', 'fg': '#1e1814', 'inactive_sym': ' 🏜'},
                       {'active_sym': '🏜 ➜ ', 'bg': '#2a9d8f', 'fg': '#ffffff', 'inactive_sym': ' 🏜'}],
        'style': 'pills',
        'use_fancy': True},
    {   'bg_bar': '#0e1a14',
        'category': 'Natureza & Tons Terrosos',
        'description': 'Copa de árvores tropicais: Esmeralda Radiante, Pinheiro Escuro, Menta Fresca e Âmbar Sol.',
        'id': 46,
        'name': 'Emerald Forest',
        'palette': [   {'active_sym': '🍃 ➜ ', 'bg': '#10b981', 'fg': '#ffffff', 'inactive_sym': ' 🍃'},
                       {'active_sym': '🍃 ➜ ', 'bg': '#059669', 'fg': '#ffffff', 'inactive_sym': ' 🍃'},
                       {'active_sym': '🍃 ➜ ', 'bg': '#34d399', 'fg': '#0e1a14', 'inactive_sym': ' 🍃'},
                       {'active_sym': '🍃 ➜ ', 'bg': '#f59e0b', 'fg': '#0e1a14', 'inactive_sym': ' 🍃'}],
        'style': 'pills',
        'use_fancy': True},
    {   'bg_bar': '#190d0d',
        'category': 'Natureza & Tons Terrosos',
        'description': 'Erupção vulcânica: Lava Vermelha, Magma Laranja, Violeta Basáltico e Enxofre Dourado.',
        'id': 47,
        'name': 'Volcanic Magma',
        'palette': [   {'active_sym': '🌋 ➜ ', 'bg': '#ef4444', 'fg': '#ffffff', 'inactive_sym': ' 🌋'},
                       {'active_sym': '🌋 ➜ ', 'bg': '#f97316', 'fg': '#ffffff', 'inactive_sym': ' 🌋'},
                       {'active_sym': '🌋 ➜ ', 'bg': '#8b5cf6', 'fg': '#ffffff', 'inactive_sym': ' 🌋'},
                       {'active_sym': '🌋 ➜ ', 'bg': '#eab308', 'fg': '#190d0d', 'inactive_sym': ' 🌋'}],
        'style': 'pills',
        'use_fancy': True},
    {   'bg_bar': '#0e191d',
        'category': 'Natureza & Tons Terrosos',
        'description': 'Fiordes nórdicos: Ciano Geleira, Azul Polar, Menta Congelada e Azul Escandinavo.',
        'id': 48,
        'name': 'Glacier Mint Ice',
        'palette': [   {'active_sym': '❄ ➜ ', 'bg': '#64dfdf', 'fg': '#0e191d', 'inactive_sym': ' ❄'},
                       {'active_sym': '❄ ➜ ', 'bg': '#48bfe3', 'fg': '#0e191d', 'inactive_sym': ' ❄'},
                       {'active_sym': '❄ ➜ ', 'bg': '#72efdd', 'fg': '#0e191d', 'inactive_sym': ' ❄'},
                       {'active_sym': '❄ ➜ ', 'bg': '#5390d9', 'fg': '#ffffff', 'inactive_sym': ' ❄'}],
        'style': 'pills',
        'use_fancy': True},
    {   'bg_bar': '#1b1411',
        'category': 'Natureza & Tons Terrosos',
        'description': 'Aroma de café torrado: Café Expresso, Caramelo Doce, Canela Queimada e Leite Cremoso.',
        'id': 49,
        'name': 'Mocha Caramel Warm',
        'palette': [   {'active_sym': '☕ ➜ ', 'bg': '#6f4e37', 'fg': '#ffffff', 'inactive_sym': ' ☕'},
                       {'active_sym': '☕ ➜ ', 'bg': '#c68b59', 'fg': '#1b1411', 'inactive_sym': ' ☕'},
                       {'active_sym': '☕ ➜ ', 'bg': '#a2583e', 'fg': '#ffffff', 'inactive_sym': ' ☕'},
                       {'active_sym': '☕ ➜ ', 'bg': '#e0a96d', 'fg': '#1b1411', 'inactive_sym': ' ☕'}],
        'style': 'pills',
        'use_fancy': True},
    {   'bg_bar': '#181a17',
        'category': 'Natureza & Tons Terrosos',
        'description': 'Equilíbrio e meditação: Musgo Verde, Areia Dourada, Bambu Escuro e Pedra Polida.',
        'id': 50,
        'name': 'Zen Garden Stone',
        'palette': [   {'active_sym': '☯ ➜ ', 'bg': '#606c38', 'fg': '#ffffff', 'inactive_sym': ' ☯'},
                       {'active_sym': '☯ ➜ ', 'bg': '#dda15e', 'fg': '#181a17', 'inactive_sym': ' ☯'},
                       {'active_sym': '☯ ➜ ', 'bg': '#283618', 'fg': '#ffffff', 'inactive_sym': ' ☯'},
                       {'active_sym': '☯ ➜ ', 'bg': '#6b705c', 'fg': '#ffffff', 'inactive_sym': ' ☯'}],
        'style': 'pills',
        'use_fancy': True},
    {   'bg_bar': '#131418',
        'category': 'Minimalista, Badges & CRT',
        'description': 'Barra vertical fina (▌) com cores vibrantes para cada aba em Azul, Vermelho, Verde e Âmbar.',
        'id': 51,
        'name': 'Left Accent Bar (▌)',
        'palette': [   {'active_sym': '▌ ', 'bg': '#3b82f6', 'fg': '#ffffff', 'inactive_sym': '▌ '},
                       {'active_sym': '▌ ', 'bg': '#ef4444', 'fg': '#ffffff', 'inactive_sym': '▌ '},
                       {'active_sym': '▌ ', 'bg': '#10b981', 'fg': '#ffffff', 'inactive_sym': '▌ '},
                       {'active_sym': '▌ ', 'bg': '#f59e0b', 'fg': '#ffffff', 'inactive_sym': '▌ '}],
        'style': 'left_bar',
        'use_fancy': False},
    {   'bg_bar': '#12141c',
        'category': 'Minimalista, Badges & CRT',
        'description': 'Linha superior de neon com brilho colorido em Ciano, Magenta, Limão e Ouro.',
        'id': 52,
        'name': 'Top Neon Highlight',
        'palette': [   {'active_sym': '▔ ', 'bg': '#00f0ff', 'fg': '#ffffff', 'inactive_sym': '  '},
                       {'active_sym': '▔ ', 'bg': '#ff007f', 'fg': '#ffffff', 'inactive_sym': '  '},
                       {'active_sym': '▔ ', 'bg': '#39ff14', 'fg': '#ffffff', 'inactive_sym': '  '},
                       {'active_sym': '▔ ', 'bg': '#ffb703', 'fg': '#ffffff', 'inactive_sym': '  '}],
        'style': 'top_neon',
        'use_fancy': False},
    {   'bg_bar': '#14151a',
        'category': 'Minimalista, Badges & CRT',
        'description': 'Abas transparentes sem contorno duro, com texto iluminado em 4 tons elegantes.',
        'id': 53,
        'name': 'Borderless Ghost Tabs',
        'palette': [   {'active_sym': '● ', 'bg': '#60a5fa', 'fg': '#ffffff', 'inactive_sym': '  '},
                       {'active_sym': '● ', 'bg': '#f87171', 'fg': '#ffffff', 'inactive_sym': '  '},
                       {'active_sym': '● ', 'bg': '#4ade80', 'fg': '#ffffff', 'inactive_sym': '  '},
                       {'active_sym': '● ', 'bg': '#facc15', 'fg': '#ffffff', 'inactive_sym': '  '}],
        'style': 'ghost',
        'use_fancy': False},
    {   'bg_bar': '#111218',
        'category': 'Minimalista, Badges & CRT',
        'description': 'Moldura neon nítida em caixas elegantes coloridas por aba.',
        'id': 54,
        'name': 'Outline Neon Frame',
        'palette': [   {'active_sym': '╭ ➜ ', 'bg': '#38bdf8', 'fg': '#ffffff', 'inactive_sym': ' '},
                       {'active_sym': '╭ ➜ ', 'bg': '#f472b6', 'fg': '#ffffff', 'inactive_sym': ' '},
                       {'active_sym': '╭ ➜ ', 'bg': '#a3e635', 'fg': '#ffffff', 'inactive_sym': ' '},
                       {'active_sym': '╭ ➜ ', 'bg': '#fbbf24', 'fg': '#ffffff', 'inactive_sym': ' '}],
        'style': 'outline',
        'use_fancy': False},
    {   'bg_bar': '#1a1b1e',
        'category': 'Minimalista, Badges & CRT',
        'description': 'Visual elegante do ecossistema Apple com as cores do sistema (Blue, Red, Green, Yellow).',
        'id': 55,
        'name': 'macOS Sonoma Dark',
        'palette': [   {'active_sym': '⚡ ➜ ', 'bg': '#0a84ff', 'fg': '#ffffff', 'inactive_sym': ' 🔘'},
                       {'active_sym': '⚡ ➜ ', 'bg': '#ff453a', 'fg': '#ffffff', 'inactive_sym': ' 🔘'},
                       {'active_sym': '⚡ ➜ ', 'bg': '#32d74b', 'fg': '#ffffff', 'inactive_sym': ' 🔘'},
                       {'active_sym': '⚡ ➜ ', 'bg': '#ffd60a', 'fg': '#1a1b1e', 'inactive_sym': ' 🔘'}],
        'style': 'pills',
        'use_fancy': True},
    {   'bg_bar': '#121316',
        'category': 'Minimalista, Badges & CRT',
        'description': 'Altura ultra-compacta economizando espaço vertical com pílulas densas e coloridas.',
        'id': 56,
        'name': 'Compact Micro Bar',
        'palette': [   {'active_sym': '➜ ', 'bg': '#38bdf8', 'fg': '#0f172a', 'inactive_sym': ''},
                       {'active_sym': '➜ ', 'bg': '#fb7185', 'fg': '#0f172a', 'inactive_sym': ''},
                       {'active_sym': '➜ ', 'bg': '#34d399', 'fg': '#0f172a', 'inactive_sym': ''},
                       {'active_sym': '➜ ', 'bg': '#fbbf24', 'fg': '#0f172a', 'inactive_sym': ''}],
        'style': 'pills',
        'use_fancy': True},
    {   'bg_bar': '#15161c',
        'category': 'Minimalista, Badges & CRT',
        'description': 'Detecta automaticamente Git, Neovim, SSH ou Docker e colore a aba dinamicamente.',
        'id': 57,
        'name': 'Smart Process & Git Context',
        'palette': [   {'active_sym': '\U000f02a2 ', 'bg': '#2563eb', 'fg': '#ffffff', 'inactive_sym': '\U000f02a2 '},
                       {'active_sym': '\U000f0169 ', 'bg': '#16a34a', 'fg': '#ffffff', 'inactive_sym': '\U000f0169 '},
                       {'active_sym': '\U000f048b ', 'bg': '#9333ea', 'fg': '#ffffff', 'inactive_sym': '\U000f048b '},
                       {'active_sym': '\U000f070e ', 'bg': '#0891b2', 'fg': '#ffffff', 'inactive_sym': '\U000f070e '}],
        'style': 'smart_badges',
        'use_fancy': True},
    {   'bg_bar': '#13141a',
        'category': 'Minimalista, Badges & CRT',
        'description': 'Círculos numéricos tipográficos ❶ ❷ ❸ ❹ em Indigo, Carmesim, Esmeralda e Ouro.',
        'id': 58,
        'name': 'Number Circle Badges (❶ ❷)',
        'palette': [   {'active_sym': '❶ ', 'bg': '#6366f1', 'fg': '#ffffff', 'inactive_sym': '❶ '},
                       {'active_sym': '❷ ', 'bg': '#e11d48', 'fg': '#ffffff', 'inactive_sym': '❷ '},
                       {'active_sym': '❸ ', 'bg': '#059669', 'fg': '#ffffff', 'inactive_sym': '❸ '},
                       {'active_sym': '❹ ', 'bg': '#d97706', 'fg': '#ffffff', 'inactive_sym': '❹ '}],
        'style': 'circle_numbers',
        'use_fancy': True},
    {   'bg_bar': '#12141a',
        'category': 'Minimalista, Badges & CRT',
        'description': 'Indicadores pulsantes circulares 🔵 🔴 🟢 🟡 indicando atividade e status da sessão.',
        'id': 59,
        'name': 'Status Pulse Dots (🟢 🟡)',
        'palette': [   {'active_sym': '🔵 ', 'bg': '#06b6d4', 'fg': '#ffffff', 'inactive_sym': '🔵 '},
                       {'active_sym': '🟢 ', 'bg': '#10b981', 'fg': '#ffffff', 'inactive_sym': '🟢 '},
                       {'active_sym': '🟣 ', 'bg': '#8b5cf6', 'fg': '#ffffff', 'inactive_sym': '🟣 '},
                       {'active_sym': '🟠 ', 'bg': '#f97316', 'fg': '#ffffff', 'inactive_sym': '🟠 '}],
        'style': 'pulse_dots',
        'use_fancy': True},
    {   'bg_bar': '#100c00',
        'category': 'Minimalista, Badges & CRT',
        'description': 'Fósforo âmbar clássico dos terminais IBM/VT100 com tons de Âmbar, Verde CRT, Ciano e Rubi.',
        'id': 60,
        'name': 'Retro Terminal Amber CRT',
        'palette': [   {'active_sym': '[* ', 'bg': '#261900', 'fg': '#ffb000', 'inactive_sym': '[- '},
                       {'active_sym': '[* ', 'bg': '#00260e', 'fg': '#33ff33', 'inactive_sym': '[- '},
                       {'active_sym': '[* ', 'bg': '#002226', 'fg': '#00ffff', 'inactive_sym': '[- '},
                       {'active_sym': '[* ', 'bg': '#260000', 'fg': '#ff3333', 'inactive_sym': '[- '}],
        'style': 'crt_amber',
        'use_fancy': False}]

def _luminance(hex_color: str) -> float:
    h = hex_color.lstrip("#")
    c = [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    c = [x / 12.92 if x <= 0.03928 else ((x + 0.055) / 1.055) ** 2.4 for x in c]
    return 0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2]


def contrast_ratio(a: str, b: str) -> float:
    hi, lo = sorted((_luminance(a), _luminance(b)), reverse=True)
    return (hi + 0.05) / (lo + 0.05)


# WCAG AA for large/bold text. Tab titles are short bold-ish labels, and 4.5:1
# would turn the white-on-Google-blue look (3.56:1) black in dozens of themes.
MIN_TAB_CONTRAST = 3.0


def readable_fg(bg: str, fg: str) -> str:
    """fg if it is readable on bg, otherwise whichever of white/near-black reads best."""
    if contrast_ratio(bg, fg) >= MIN_TAB_CONTRAST:
        return fg
    return max(("#ffffff", "#1a1a1a"), key=lambda c: contrast_ratio(bg, c))


# Unreadable text colors (e.g. white on #FBBC05, 1.7:1) are fixed at load time,
# so the picker previews and the generated Lua get the same readable colors.
for _theme in THEMES:
    for _p in _theme["palette"]:
        _p["fg"] = readable_fg(_p["bg"], _p["fg"])


def project_slot(name: str, size: int) -> int:
    """Stable 0-based palette slot for a project name; mirrors the Lua in project_color."""
    h = 0
    for b in name.encode("utf-8"):
        h = (h * 31 + b) % 2147483648
    return h % size


def get_theme_by_id(theme_id: int) -> dict | None:
    for t in THEMES:
        if t["id"] == theme_id:
            return t
    return None

def find_theme(query: str) -> dict | None:
    """Find a theme by numeric ID (e.g. '10', '#10', '01') or name substring."""
    q = query.strip()
    q_num = q.lstrip("#").strip()
    if q_num.isdigit():
        return get_theme_by_id(int(q_num))
    q_lower = q.lower()
    for t in THEMES:
        if t["name"].lower() == q_lower:
            return t
    for t in THEMES:
        if q_lower in t["name"].lower():
            return t
    return None

# ── Symbol builder ──────────────────────────────────────────────────────────
# The active-tab symbol is composed as "<prefix> <marker> <arrow> " and the
# inactive one as " <inactive>". A marker holds one glyph per palette color
# (tab 1..4) or a single glyph shared by all tabs. Emoji with a VS16
# selector (e.g. ❤️) are left out: terminals disagree on their width.
SYMBOL_PREFIXES = [
    {"key": "none", "name": "Nenhum", "chars": [""]},
    {"key": "bolt", "name": "Raio", "chars": ["⚡"]},
    {"key": "fire", "name": "Fogo", "chars": ["🔥"]},
    {"key": "sparkles", "name": "Brilho", "chars": ["✨"]},
    {"key": "rocket", "name": "Foguete", "chars": ["🚀"]},
    {"key": "star", "name": "Estrela", "chars": ["★"]},
    {"key": "diamond", "name": "Losango", "chars": ["◆"]},
    {"key": "flag", "name": "Bandeira", "chars": ["\U000f023b"]},
]

# Colored markers ("match") pick, per tab, the emoji whose color is closest to
# that tab's background, so a red tab gets 🔴 whatever the palette order.
# Reference colors approximate Noto Color Emoji.
_EMOJI_COLORS = {
    "red": "#e53935", "orange": "#fb8c00", "yellow": "#fdd835", "green": "#43a047",
    "blue": "#1e88e5", "purple": "#8e24aa", "black": "#212121", "white": "#eeeeee",
}
_BALLS = {"red": "🔴", "orange": "🟠", "yellow": "🟡", "green": "🟢", "blue": "🔵",
          "purple": "🟣", "black": "⚫", "white": "⚪"}
_SQUARES = {"red": "🟥", "orange": "🟧", "yellow": "🟨", "green": "🟩", "blue": "🟦",
            "purple": "🟪", "black": "⬛", "white": "⬜"}
# No red heart: ❤️ needs a VS16 selector, whose width terminals disagree on.
# No brown anywhere: its hue is orange's, so orange tabs would turn brown.
_HEARTS = {"orange": "🧡", "yellow": "💛", "green": "💚", "blue": "💙",
           "purple": "💜", "black": "🖤", "white": "🤍"}

SYMBOL_MARKERS = [
    {"key": "none", "name": "Nenhum", "chars": [""]},
    {"key": "balls", "name": "Bolas (cor da aba)", "match": _BALLS,
     "chars": ["🔴", "🟠", "🟡", "🟢", "🔵", "🟣"]},
    {"key": "balls_google", "name": "Bolas Google fixas", "chars": ["🔵", "🔴", "🟢", "🟠"]},
    {"key": "squares", "name": "Quadrados (cor da aba)", "match": _SQUARES,
     "chars": ["🟥", "🟧", "🟨", "🟩", "🟦", "🟪"]},
    {"key": "hearts", "name": "Corações (cor da aba)", "match": _HEARTS,
     "chars": ["🧡", "💛", "💚", "💙", "💜"]},
    {"key": "moons", "name": "Luas", "chars": ["🌑", "🌓", "🌕", "🌗"]},
    {"key": "dot", "name": "Ponto", "chars": ["●"]},
    {"key": "ring", "name": "Anel", "chars": ["◉"]},
    {"key": "square", "name": "Quadrado", "chars": ["■"]},
    {"key": "triangle", "name": "Triângulo", "chars": ["▶"]},
    {"key": "circled", "name": "Números ❶", "chars": ["❶", "❷", "❸", "❹"]},
    {"key": "nerd", "name": "Ícones Nerd", "chars": ["\U000f02a2", "\U000f0169", "\U000f048b", "\U000f070e"]},
]

SYMBOL_ARROWS = [
    {"key": "none", "name": "Nenhuma", "chars": [""]},
    {"key": "arrow", "name": "Seta grossa", "chars": ["➜"]},
    {"key": "chevron", "name": "Chevron", "chars": ["❯"]},
    {"key": "play", "name": "Play", "chars": ["▶"]},
    {"key": "guillemet", "name": "Aspas »", "chars": ["»"]},
    {"key": "thin", "name": "Seta fina", "chars": ["→"]},
    {"key": "angle", "name": "Ângulo", "chars": ["⟩"]},
    {"key": "powerline", "name": "Powerline", "chars": [""]},
]

SYMBOL_INACTIVE = [
    {"key": "none", "name": "Nenhum", "chars": [""]},
    {"key": "radio", "name": "Botão 🔘", "chars": ["🔘"]},
    {"key": "same", "name": "Igual ao marcador", "chars": None},
    {"key": "circle", "name": "Círculo", "chars": ["○"]},
    {"key": "middot", "name": "Ponto médio", "chars": ["·"]},
    {"key": "diamond", "name": "Losango vazado", "chars": ["◇"]},
    {"key": "white", "name": "Bola branca", "chars": ["⚪"]},
    {"key": "dash", "name": "Traço", "chars": ["–"]},
]

# The look of the classic Google theme: "⚡ 🔵 ➜ 1 setup" / "2 🔘 mvsoares".
DEFAULT_SYMBOLS = {"prefix": "bolt", "marker": "balls", "arrow": "arrow", "inactive": "radio"}

SYMBOL_GROUPS = [
    ("prefix", "p", "Prefixo", SYMBOL_PREFIXES),
    ("marker", "m", "Marcador", SYMBOL_MARKERS),
    ("arrow", "a", "Seta", SYMBOL_ARROWS),
    ("inactive", "i", "Aba inativa", SYMBOL_INACTIVE),
]

# Styles whose format-tab-title ignores active_sym/inactive_sym.
NO_SYMBOL_STYLES = {"smart_badges", "circle_numbers", "crt_amber", "left_bar", "top_neon", "ghost", "outline"}


def theme_uses_symbols(t: dict) -> bool:
    return t.get("style", "pills") not in NO_SYMBOL_STYLES


def _symbol_option(options: list[dict], key: str) -> dict:
    return next((o for o in options if o["key"] == key), options[0])


def _glyph(option: dict, i: int) -> str:
    chars = option["chars"] or [""]
    return chars[i % len(chars)]


def _lch(hex_color: str) -> tuple[float, float, float]:
    """CIE LCh (lightness, chroma, hue in degrees) of an sRGB hex color."""
    h = hex_color.lstrip("#")
    rgb = [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    r, g, b = [c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4 for c in rgb]
    xyz = ((0.4124 * r + 0.3576 * g + 0.1805 * b) / 0.95047,
           0.2126 * r + 0.7152 * g + 0.0722 * b,
           (0.0193 * r + 0.1192 * g + 0.9505 * b) / 1.08883)
    fx, fy, fz = [t ** (1 / 3) if t > 0.008856 else 7.787 * t + 16 / 116 for t in xyz]
    a, bb = 500 * (fx - fy), 200 * (fy - fz)
    return 116 * fy - 16, math.hypot(a, bb), math.degrees(math.atan2(bb, a)) % 360


def matching_glyph(option: dict, bg: str) -> str:
    """The emoji of a "match" marker whose color is closest to bg.

    Chromatic backgrounds are matched by hue, so dark or pastel tabs still get
    their hue's emoji; near-gray ones get black or white by lightness.
    """
    glyphs = option["match"]
    light, chroma, hue = _lch(bg)
    if chroma < 12:
        gray = "black" if light < 50 else "white"
        if gray in glyphs:
            return glyphs[gray]

    def hue_gap(name: str) -> float:
        _, c, h = _lch(_EMOJI_COLORS[name])
        gap = abs(h - hue) % 360
        return min(gap, 360 - gap) if c >= 12 else 999.0

    return glyphs[min(glyphs, key=hue_gap)]


def compose_symbols(sel: dict, i: int, bg: str | None = None) -> tuple[str, str]:
    """Return (active_sym, inactive_sym) for palette slot i, whose tab color is bg."""
    sel = {**DEFAULT_SYMBOLS, **sel}
    marker_opt = _symbol_option(SYMBOL_MARKERS, sel["marker"])
    if "match" in marker_opt and bg:
        marker = matching_glyph(marker_opt, bg)
    else:
        marker = _glyph(marker_opt, i)
    parts = [
        _glyph(_symbol_option(SYMBOL_PREFIXES, sel["prefix"]), i),
        marker,
        _glyph(_symbol_option(SYMBOL_ARROWS, sel["arrow"]), i),
    ]
    parts = [p for p in parts if p]
    active = " ".join(parts) + " " if parts else ""
    inactive_opt = _symbol_option(SYMBOL_INACTIVE, sel["inactive"])
    inactive = marker if inactive_opt["chars"] is None else _glyph(inactive_opt, i)
    return active, (f" {inactive}" if inactive else "")


def apply_symbols(t: dict, sel: dict | None) -> dict:
    """Copy of theme t with its palette symbols replaced by selection sel."""
    if not sel:
        return t
    palette = []
    for i, p in enumerate(t.get("palette", [])):
        active, inactive = compose_symbols(sel, i, p["bg"])
        palette.append({**p, "active_sym": active, "inactive_sym": inactive})
    return {**t, "palette": palette}


def generate_lua_for_theme(t: dict, tab_title_len: int = 15, symbols: dict | None = None) -> str:
    """Produce Lua code for ~/.config/wezterm/tab_theme.lua.

    Guarantees every theme applies 4-color cycling across all open tabs,
    and formats tab text with uniform fixed length (tab_title_len, default 15).
    symbols, when set, overrides the theme's tab symbols (see compose_symbols)
    and is recorded in a "-- Symbols:" header line so it can be read back.
    """
    t = apply_symbols(t, symbols)
    style = t.get("style", "pills")
    use_fancy = t.get("use_fancy", True)
    bg_bar = t.get("bg_bar", "#15161c")
    palette = t.get("palette", [
        {"bg": "#4285F4", "fg": "#ffffff", "active_sym": "⚡ 🔵 ➜ ", "inactive_sym": " 🔘"},
        {"bg": "#EA4335", "fg": "#ffffff", "active_sym": "⚡ 🔴 ➜ ", "inactive_sym": " 🔘"},
        {"bg": "#34A853", "fg": "#ffffff", "active_sym": "⚡ 🟢 ➜ ", "inactive_sym": " 🔘"},
        {"bg": "#FBBC05", "fg": "#ffffff", "active_sym": "⚡ 🟠 ➜ ", "inactive_sym": " 🔘"},
    ])

    lua = [
        f"-- Auto-generated by WezTerm Tab Theme Picker",
        f"-- Theme #{t['id']:02d}: {t['name']} ({t['category']})",
        f"-- Style: {style}",
        *([f"-- Symbols: {json.dumps(symbols, ensure_ascii=False, sort_keys=True)}"] if symbols else []),
        f"",
        f"local M = {{}}",
        f"",
        f"function M.apply(config, wezterm)",
        f"  config.use_fancy_tab_bar = {str(use_fancy).lower()}",
        f"  config.tab_bar_at_bottom = true",
        f"  config.show_tab_index_in_tab_bar = false",
        f"  config.tab_max_width = 36",
        f"  config.colors = config.colors or {{}}",
        f"  config.colors.tab_bar = {{",
        f"    background = '{bg_bar}',",
        f"    active_tab = {{ bg_color = '{palette[0]['bg']}', fg_color = '{palette[0]['fg']}' }},",
        f"    inactive_tab = {{ bg_color = '{palette[1]['bg']}', fg_color = '{palette[1]['fg']}' }},",
        f"    inactive_tab_hover = {{ bg_color = '{palette[2]['bg']}', fg_color = '{palette[2]['fg']}' }},",
        f"    new_tab = {{ bg_color = '{bg_bar}', fg_color = '#64748b' }},",
        f"    new_tab_hover = {{ bg_color = '{palette[0]['bg']}', fg_color = '{palette[0]['fg']}' }},",
        f"  }}",
        f"  -- The fancy tab bar paints its strip with the window frame colors, not",
        f"  -- colors.tab_bar.background; keep them on the theme's bar color.",
        f"  if config.use_fancy_tab_bar then",
        f"    config.window_frame = config.window_frame or {{}}",
        f"    config.window_frame.active_titlebar_bg = '{bg_bar}'",
        f"    config.window_frame.inactive_titlebar_bg = '{bg_bar}'",
        f"  end",
        f"",
        f"  local TAB_TITLE_LEN = {int(tab_title_len)}",
        f"",
        f"  local function format_fixed(text, len)",
        f"    len = len or TAB_TITLE_LEN",
        f"    local w = wezterm.column_width(text)",
        f"    if w > len then",
        f"      return wezterm.truncate_right(text, len - 1) .. '…'",
        f"    else",
        f"      return wezterm.pad_right(text, len)",
        f"    end",
        f"  end",
        f"",
        f"  local function get_title_info(tab)",
        f"    local pane = tab.active_pane",
        f"    local index = tab.tab_index + 1",
        f"    local cwd_uri = pane.current_working_dir",
        f"    local dir = '~'",
        f"    if cwd_uri then",
        f"      local cwd = cwd_uri.file_path",
        f"      dir = cwd:match('([^/]+)/?$') or cwd",
        f"    end",
        f"    local uv_cmd = (pane.user_vars or {{}}).cmd or ''",
        f"    local fg = pane.foreground_process_name or ''",
        f"    local process = uv_cmd ~= '' and uv_cmd or (fg:match('([^/\\\\]+)$') or '')",
        f"    if process == 'bash' or process == 'zsh' or process == 'fish' or process == 'tmux' or process == 'wezterm' then",
        f"      process = ''",
        f"    end",
        f"    local label = dir",
        f"    if process ~= '' then",
        f"      label = process .. '|' .. dir",
        f"    end",
        f"    label = format_fixed(label, TAB_TITLE_LEN)",
        f"    return index, label, process, dir",
        f"  end",
        f"",
    ]

    palette_entries = []
    for p in palette:
        act_s = p.get("active_sym", "⚡ ➜ ").replace("'", "\'")
        inact_s = p.get("inactive_sym", " 🔘").replace("'", "\'")
        palette_entries.append(f"    {{ bg = '{p['bg']}', fg = '{p['fg']}', active_sym = '{act_s}', inactive_sym = '{inact_s}' }},")

    lua.extend([
        f"  local palette = {{",
        *palette_entries,
        f"  }}",
        f"",
    ])

    if style == "powerline":
        sep = t.get("sep_char", "\\u{e0b0}")
        if sep in ("\\ue0b0", "\ue0b0", ""): sep = "\\u{e0b0}"
        elif sep in ("\\ue0b4", "\ue0b4", ""): sep = "\\u{e0b4}"
        elif sep in ("\\ue0bc", "\ue0bc", ""): sep = "\\u{e0bc}"
        elif sep in ("\\ue0c0", "\ue0c0", ""): sep = "\\u{e0c0}"
        elif sep in ("\\ue0b1", "\ue0b1", ""): sep = "\\u{e0b1}"
        elif sep in ("\\ue0cc", "\ue0cc", ""): sep = "\\u{e0cc}"
        elif sep in ("\\ue0ca", "\ue0ca", ""): sep = "\\u{e0ca}"
        elif sep in ("\\ue0c8", "\ue0c8", ""): sep = "\\u{e0c8}"
        elif sep in ("\\ue0c4", "\ue0c4", ""): sep = "\\u{e0c4}"
        elif sep in ("\\u2571", "\u2571", "╱"): sep = "\\u{2571}"

        lua.extend([
            f"  wezterm.on('format-tab-title', function(tab, tabs, panes, config, hover, max_width)",
            f"    local index, label, process, dir = get_title_info(tab)",
            f"    local is_act = tab.is_active",
            f"    local c = palette[(tab.tab_index % #palette) + 1]",
            f"    local next_bg = '{bg_bar}'",
            f"    if tabs and tab.tab_index + 1 < #tabs then",
            f"      local next_tab = tabs[tab.tab_index + 2]",
            f"      local next_c = palette[(next_tab.tab_index % #palette) + 1]",
            f"      next_bg = next_c.bg",
            f"    end",
            f"    local text = is_act and (c.active_sym .. index) or (index .. c.inactive_sym)",
            f"    return wezterm.format {{",
            f"      {{ Background = {{ Color = c.bg }} }},",
            f"      {{ Foreground = {{ Color = c.fg }} }},",
            f"      {{ Attribute = {{ Intensity = is_act and 'Bold' or 'Normal' }} }},",
            f"      {{ Attribute = {{ Underline = is_act and 'Single' or 'None' }} }},",
            f"      {{ Text = ' ' .. text .. ' ' .. label .. ' ' }},",
            f"      {{ Background = {{ Color = next_bg }} }},",
            f"      {{ Foreground = {{ Color = c.bg }} }},",
            f"      {{ Text = '{sep}' }},",
            f"    }}",
            f"  end)",
        ])
    elif style == "smart_badges":
        lua.extend([
            f"  local function get_icon(process)",
            f"    if process:find('git') then return '󰊢 '",
            f"    elseif process:find('nvim') or process:find('vim') then return '󰅩 '",
            f"    elseif process:find('ssh') then return '󰒋 '",
            f"    elseif process:find('python') then return ' '",
            f"    elseif process:find('docker') then return '󰜎 '",
            f"    else return ' ' end",
            f"  end",
            f"",
            f"  wezterm.on('format-tab-title', function(tab, tabs, panes, config, hover, max_width)",
            f"    local index, label, process, dir = get_title_info(tab)",
            f"    local icon = get_icon(process)",
            f"    local is_act = tab.is_active",
            f"    local c = palette[(tab.tab_index % #palette) + 1]",
            f"    return wezterm.format {{",
            f"      {{ Background = {{ Color = c.bg }} }},",
            f"      {{ Foreground = {{ Color = c.fg }} }},",
            f"      {{ Attribute = {{ Intensity = is_act and 'Bold' or 'Normal' }} }},",
            f"      {{ Attribute = {{ Underline = is_act and 'Single' or 'None' }} }},",
            f"      {{ Text = ' ' .. icon .. index .. ' ' .. label .. ' ✕ ' }},",
            f"    }}",
            f"  end)",
        ])
    elif style == "circle_numbers":
        lua.extend([
            f"  local circles = {{ '❶', '❷', '❸', '❹', '❺', '❻', '❼', '❽', '❾', '❿' }}",
            f"  wezterm.on('format-tab-title', function(tab, tabs, panes, config, hover, max_width)",
            f"    local index, label, process, dir = get_title_info(tab)",
            f"    local num = circles[index] or tostring(index)",
            f"    local is_act = tab.is_active",
            f"    local c = palette[(tab.tab_index % #palette) + 1]",
            f"    return wezterm.format {{",
            f"      {{ Background = {{ Color = c.bg }} }},",
            f"      {{ Foreground = {{ Color = c.fg }} }},",
            f"      {{ Attribute = {{ Intensity = is_act and 'Bold' or 'Normal' }} }},",
            f"      {{ Attribute = {{ Underline = is_act and 'Single' or 'None' }} }},",
            f"      {{ Text = ' ' .. num .. ' ' .. label .. ' ✕ ' }},",
            f"    }}",
            f"  end)",
        ])
    elif style == "pulse_dots":
        lua.extend([
            f"  wezterm.on('format-tab-title', function(tab, tabs, panes, config, hover, max_width)",
            f"    local index, label, process, dir = get_title_info(tab)",
            f"    local is_act = tab.is_active",
            f"    local c = palette[(tab.tab_index % #palette) + 1]",
            f"    local dot = is_act and c.active_sym or c.inactive_sym",
            f"    return wezterm.format {{",
            f"      {{ Background = {{ Color = c.bg }} }},",
            f"      {{ Foreground = {{ Color = c.fg }} }},",
            f"      {{ Attribute = {{ Intensity = is_act and 'Bold' or 'Normal' }} }},",
            f"      {{ Attribute = {{ Underline = is_act and 'Single' or 'None' }} }},",
            f"      {{ Text = ' ' .. dot .. index .. ' ' .. label .. ' ✕ ' }},",
            f"    }}",
            f"  end)",
        ])
    elif style == "crt_amber":
        lua.extend([
            f"  wezterm.on('format-tab-title', function(tab, tabs, panes, config, hover, max_width)",
            f"    local index, label, process, dir = get_title_info(tab)",
            f"    local is_act = tab.is_active",
            f"    local c = palette[(tab.tab_index % #palette) + 1]",
            f"    local marker = is_act and '*' or '-'",
            f"    return wezterm.format {{",
            f"      {{ Background = {{ Color = c.bg }} }},",
            f"      {{ Foreground = {{ Color = c.fg }} }},",
            f"      {{ Attribute = {{ Intensity = is_act and 'Bold' or 'Normal' }} }},",
            f"      {{ Attribute = {{ Underline = is_act and 'Single' or 'None' }} }},",
            f"      {{ Text = ' [' .. marker .. ' ' .. string.format('%02d', index) .. ':' .. label:upper() .. ' ' .. marker .. '] ' }},",
            f"    }}",
            f"  end)",
        ])
    elif style == "left_bar":
        lua.extend([
            f"  wezterm.on('format-tab-title', function(tab, tabs, panes, config, hover, max_width)",
            f"    local index, label, process, dir = get_title_info(tab)",
            f"    local is_act = tab.is_active",
            f"    local c = palette[(tab.tab_index % #palette) + 1]",
            f"    local prefix = is_act and '▌ ' or '  '",
            f"    return wezterm.format {{",
            f"      {{ Background = {{ Color = is_act and c.bg or '#1a1c23' }} }},",
            f"      {{ Foreground = {{ Color = is_act and c.fg or c.bg }} }},",
            f"      {{ Attribute = {{ Intensity = is_act and 'Bold' or 'Normal' }} }},",
            f"      {{ Attribute = {{ Underline = is_act and 'Single' or 'None' }} }},",
            f"      {{ Text = prefix .. index .. ' ' .. label .. ' ✕ ' }},",
            f"    }}",
            f"  end)",
        ])
    elif style == "top_neon":
        lua.extend([
            f"  wezterm.on('format-tab-title', function(tab, tabs, panes, config, hover, max_width)",
            f"    local index, label, process, dir = get_title_info(tab)",
            f"    local is_act = tab.is_active",
            f"    local c = palette[(tab.tab_index % #palette) + 1]",
            f"    return wezterm.format {{",
            f"      {{ Background = {{ Color = is_act and c.bg or '#151720' }} }},",
            f"      {{ Foreground = {{ Color = is_act and c.fg or c.bg }} }},",
            f"      {{ Attribute = {{ Intensity = is_act and 'Bold' or 'Normal' }} }},",
            f"      {{ Attribute = {{ Underline = is_act and 'Single' or 'None' }} }},",
            f"      {{ Text = ' ▔ ' .. index .. ' ' .. label .. ' ✕ ' }},",
            f"    }}",
            f"  end)",
        ])
    elif style == "ghost":
        lua.extend([
            f"  wezterm.on('format-tab-title', function(tab, tabs, panes, config, hover, max_width)",
            f"    local index, label, process, dir = get_title_info(tab)",
            f"    local is_act = tab.is_active",
            f"    local c = palette[(tab.tab_index % #palette) + 1]",
            f"    return wezterm.format {{",
            f"      {{ Background = {{ Color = is_act and '#252836' or '{bg_bar}' }} }},",
            f"      {{ Foreground = {{ Color = c.bg }} }},",
            f"      {{ Attribute = {{ Intensity = is_act and 'Bold' or 'Normal' }} }},",
            f"      {{ Attribute = {{ Underline = is_act and 'Single' or 'None' }} }},",
            f"      {{ Text = ' ' .. index .. ' ' .. label .. ' ✕ ' }},",
            f"    }}",
            f"  end)",
        ])
    elif style == "project_color":
        lua.extend([
            f"  -- Same hash as project_slot() in wezterm_tab_themes.py: a project keeps its color.",
            f"  local function project_slot(name)",
            f"    local h = 0",
            f"    for i = 1, #name do",
            f"      h = (h * 31 + name:byte(i)) % 2147483648",
            f"    end",
            f"    return (h % #palette) + 1",
            f"  end",
            f"",
            f"  wezterm.on('format-tab-title', function(tab, tabs, panes, config, hover, max_width)",
            f"    local index, label, process, dir = get_title_info(tab)",
            f"    local is_act = tab.is_active",
            f"    local c = palette[project_slot(dir)]",
            f"    local text = is_act and (c.active_sym .. index) or (index .. c.inactive_sym)",
            f"    return wezterm.format {{",
            f"      {{ Background = {{ Color = c.bg }} }},",
            f"      {{ Foreground = {{ Color = c.fg }} }},",
            f"      {{ Attribute = {{ Intensity = is_act and 'Bold' or 'Normal' }} }},",
            f"      {{ Attribute = {{ Underline = is_act and 'Single' or 'None' }} }},",
            f"      {{ Text = ' ' .. text .. ' ' .. label .. ' ✕ ' }},",
            f"    }}",
            f"  end)",
        ])
    elif style == "activity":
        alert = t.get("alert_color", "#fdd663")
        lua.extend([
            f"  -- Remote sessions keep ssh/shpool in the foreground forever; don't flag them busy.",
            f"  local not_busy = {{ ssh = true, shpool = true, mosh = true, ['mosh-client'] = true }}",
            f"",
            f"  wezterm.on('format-tab-title', function(tab, tabs, panes, config, hover, max_width)",
            f"    local index, label, process, dir = get_title_info(tab)",
            f"    local is_act = tab.is_active",
            f"    local c = palette[(tab.tab_index % #palette) + 1]",
            f"    local items = {{",
            f"      {{ Background = {{ Color = c.bg }} }},",
            f"      {{ Foreground = {{ Color = c.fg }} }},",
            f"      {{ Attribute = {{ Intensity = is_act and 'Bold' or 'Normal' }} }},",
            f"      {{ Attribute = {{ Underline = is_act and 'Single' or 'None' }} }},",
            f"      {{ Text = ' ' }},",
            f"    }}",
            f"    if not is_act and tab.active_pane.has_unseen_output then",
            f"      table.insert(items, {{ Foreground = {{ Color = '{alert}' }} }})",
            f"      table.insert(items, {{ Text = '● ' }})",
            f"      table.insert(items, {{ Foreground = {{ Color = c.fg }} }})",
            f"    end",
            f"    if process ~= '' and not not_busy[process] then",
            f"      table.insert(items, {{ Text = '⏳ ' }})",
            f"    end",
            f"    local text = is_act and (c.active_sym .. index) or (index .. c.inactive_sym)",
            f"    table.insert(items, {{ Text = text .. ' ' .. label .. ' ✕ ' }})",
            f"    return wezterm.format(items)",
            f"  end)",
        ])
    elif style == "mono_accent":
        muted_bg = t.get("muted_bg", "#303134")
        muted_fg = t.get("muted_fg", "#9aa0a6")
        lua.extend([
            f"  wezterm.on('format-tab-title', function(tab, tabs, panes, config, hover, max_width)",
            f"    local index, label, process, dir = get_title_info(tab)",
            f"    local c = palette[(tab.tab_index % #palette) + 1]",
            f"    if tab.is_active then",
            f"      return wezterm.format {{",
            f"        {{ Background = {{ Color = c.bg }} }},",
            f"        {{ Foreground = {{ Color = c.fg }} }},",
            f"        {{ Attribute = {{ Intensity = 'Bold' }} }},",
            f"        {{ Text = ' ' .. c.active_sym .. index .. ' ' .. label .. ' ✕ ' }},",
            f"      }}",
            f"    end",
            f"    return wezterm.format {{",
            f"      {{ Background = {{ Color = '{muted_bg}' }} }},",
            f"      {{ Foreground = {{ Color = c.bg }} }},",
            f"      {{ Attribute = {{ Intensity = 'Bold' }} }},",
            f"      {{ Text = ' ' .. index }},",
            f"      {{ Attribute = {{ Intensity = 'Normal' }} }},",
            f"      {{ Foreground = {{ Color = '{muted_fg}' }} }},",
            f"      {{ Text = c.inactive_sym .. ' ' .. label .. ' ✕ ' }},",
            f"    }}",
            f"  end)",
        ])
    elif style == "outline":
        lua.extend([
            f"  wezterm.on('format-tab-title', function(tab, tabs, panes, config, hover, max_width)",
            f"    local index, label, process, dir = get_title_info(tab)",
            f"    local is_act = tab.is_active",
            f"    local c = palette[(tab.tab_index % #palette) + 1]",
            f"    local frame = is_act and '【' or '〔'",
            f"    local frame_end = is_act and '】' or '〕'",
            f"    return wezterm.format {{",
            f"      {{ Background = {{ Color = is_act and c.bg or '#161822' }} }},",
            f"      {{ Foreground = {{ Color = is_act and c.fg or c.bg }} }},",
            f"      {{ Attribute = {{ Intensity = is_act and 'Bold' or 'Normal' }} }},",
            f"      {{ Attribute = {{ Underline = is_act and 'Single' or 'None' }} }},",
            f"      {{ Text = ' ' .. frame .. index .. ' ' .. label .. frame_end .. ' ' }},",
            f"    }}",
            f"  end)",
        ])
    else:
        # Default: full color cycling tabs (pills / google_cycle / palette_cycle)
        lua.extend([
            f"  wezterm.on('format-tab-title', function(tab, tabs, panes, config, hover, max_width)",
            f"    local index, label, process, dir = get_title_info(tab)",
            f"    local is_act = tab.is_active",
            f"    local c = palette[(tab.tab_index % #palette) + 1]",
            f"    if is_act then",
            f"      return wezterm.format {{",
            f"        {{ Background = {{ Color = c.bg }} }},",
            f"        {{ Foreground = {{ Color = c.fg }} }},",
            f"        {{ Attribute = {{ Intensity = 'Bold' }} }},",
            f"        {{ Attribute = {{ Underline = 'Single' }} }},",
            f"        {{ Text = ' ' .. c.active_sym .. index .. ' ' .. label .. ' ✕ ' }},",
            f"      }}",
            f"    else",
            f"      return wezterm.format {{",
            f"        {{ Background = {{ Color = c.bg }} }},",
            f"        {{ Foreground = {{ Color = c.fg }} }},",
            f"        {{ Text = ' ' .. index .. c.inactive_sym .. ' ' .. label .. ' ✕ ' }},",
            f"      }}",
            f"    end",
            f"  end)",
        ])

    lua.extend([
        f"end",
        f"",
        f"return M",
    ])
    return "\n".join(lua)

return {
	Variants = {
		Primary = {
			Background = Color3.fromRGB(54, 82, 227),
		},
		Secondary = {
			Background = Color3.fromRGB(42, 43, 49)
		},
		Danger = {
			Background = Color3.fromRGB(227, 54, 82)
		},
		Success = {
			Background = Color3.fromRGB(0,165,82)
		},
		Ghost = {
			Transparency = 1
		},
		Outline = {
			Transparency = 1,
			Background = Color3.fromRGB(54, 82, 227),
			Color = Color3.fromRGB(27, 42, 53)
		},
	},

	Colors = {
		Brand = {
			BrandWhite      = Color3.fromRGB(255, 255, 255),
			BrandLightGray  = Color3.fromRGB(61,  61,  61),
			BrandGray       = Color3.fromRGB(42,  43,  49),
			BrandBackground = Color3.fromRGB(25,  26,  31),
			BrandBlue       = Color3.fromRGB(54,  82,  227),
			BrandRed        = Color3.fromRGB(227, 54,  82),
			BrandGreen      = Color3.fromRGB(34,  197, 120),
			BrandYellow     = Color3.fromRGB(245, 158, 11),
		},

		Surface = {
			Base    = Color3.fromRGB(25,  26,  31),
			Raised  = Color3.fromRGB(32,  33,  40),
			Overlay = Color3.fromRGB(42,  43,  49),
			Border  = Color3.fromRGB(55,  56,  65),
			Subtle  = Color3.fromRGB(70,  71,  82),
		},

		Text = {
			Primary   = Color3.fromRGB(240, 240, 245),
			Secondary = Color3.fromRGB(160, 161, 175),
			Disabled  = Color3.fromRGB(90,  91,  105),
			Inverse   = Color3.fromRGB(15,  15,  20),
		},

		State = {
			Hover   = Color3.fromRGB(255, 255, 255),
			Press   = Color3.fromRGB(0,   0,   0),
			Focus   = Color3.fromRGB(54,  82,  227),
			Success = Color3.fromRGB(34,  197, 120),
			Warning = Color3.fromRGB(245, 158, 11),
			Error   = Color3.fromRGB(227, 54,  82),
			Info    = Color3.fromRGB(95,  155, 255),
		},

		Link  = Color3.fromRGB(95,  155, 255),
		Scrim = Color3.fromRGB(0,   0,   0),
	},

	Text = {
		Font       = Font.new(Enum.Font.BuilderSans.Value,     Enum.FontWeight.Bold),
		FontMedium = Font.new(Enum.Font.BuilderSans.Value,     Enum.FontWeight.Medium),
		FontBold   = Font.new(Enum.Font.BuilderSans.Value, Enum.FontWeight.Bold),

		SizeXS      = 10,
		SizeSM      = 12,
		SizeMD      = 14,
		SizeLG      = 16,
		SizeXL      = 20,
		SizeTitle   = 18,
		SizeDisplay = 24,
	},

	Sizes = {
		ContainerSize     = UDim2.fromOffset(450, 280),
		ContainerPosition = UDim2.fromScale(0.5, 0.5),

		InputHeight   = 36,
		ButtonHeight  = 36,
		LabelHeight   = 22,
		DividerHeight = 1,

		IconSM = 16,
		IconMD = 20,
		IconLG = 28,
	},

	Roundness = {
		None = UDim.new(0, 0),
		SM   = UDim.new(0, 4),
		MD   = UDim.new(0, 8),
		LG   = UDim.new(0, 12),
		XL   = UDim.new(0, 16),
		Full = UDim.new(1, 0),

		CornerRoundness = UDim.new(0, 16),
		ButtonRoundness = UDim.new(0, 8),
		InputRoundness  = UDim.new(0, 8),
		BadgeRoundness  = UDim.new(1, 0),
	},

	Motion = {
		DurationFast   = 0.08,   -- Roblox native UI is snappier
		DurationNormal = 0.15,
		DurationSlow   = 0.25,

		EasingOut  = Enum.EasingStyle.Quad,
		EasingIn   = Enum.EasingStyle.Quad,
		EasingBack = Enum.EasingStyle.Back,
	},

	Spacing = {
		XS  = UDim.new(0, 4),
		SM  = UDim.new(0, 8),
		MD  = UDim.new(0, 12),
		LG  = UDim.new(0, 16),
		XL  = UDim.new(0, 24),
		XXL = UDim.new(0, 32),
	},

	ZIndex = {
		{ name = "Background", base = 1   },
		{ name = "Content",    base = 10  },
		{ name = "Raised",     base = 20  },
		{ name = "Floating",   base = 50  },
		{ name = "Overlay",    base = 80  },
		{ name = "Tooltip",    base = 100 },
		{ name = "Toast",      base = 110 },
		{ name = "System",     base = 120 },
	},

	Opacity = {
		ScrimLight = 0.35,
		ScrimHeavy = 0.60,
		Disabled   = 0.40,
		Subtle     = 0.06,
	},
}
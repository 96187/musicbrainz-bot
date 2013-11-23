use utf8;

sub mapping {
	my %mapping = (

		# Germany
		"Rock am Ring, Nürburgring, Germany" => "7643f13a-dcda-4db4-8196-3ffcc1b99ab7",
		"Philipshalle, Düsseldorf, Germany" => "c250a79e-da32-4c07-a93f-cbddaab51288",

		# Japan
		"Budokan, Tokyo, Japan" => "4d43b9d8-162d-4ac5-8068-dfb009722484",
		"Budokan Hall, Tokyo, Japan" => "4d43b9d8-162d-4ac5-8068-dfb009722484",
		"Nippon Budōkan, Tōkyō, Japan" => "4d43b9d8-162d-4ac5-8068-dfb009722484",
		"日本武道館, Tōkyō, Japan" => "4d43b9d8-162d-4ac5-8068-dfb009722484",
		"日本武道館, Tokyo, Japan" => "4d43b9d8-162d-4ac5-8068-dfb009722484",
		"Nippon Budokan Hall, Tokyo, Japan" => "4d43b9d8-162d-4ac5-8068-dfb009722484",
		"Nippon Budokan, Tokyo, Japan" => "4d43b9d8-162d-4ac5-8068-dfb009722484",
		"Nakano Sunplaza, Tokyo, Japan" => "44f57837-8773-4e69-b0e7-3360ddbe278a",
		"Nakano Sun Plaza, Tokyo, Japan" => "44f57837-8773-4e69-b0e7-3360ddbe278a",
		"Nakano SUNPLAZA, Japan" => "44f57837-8773-4e69-b0e7-3360ddbe278a",
		"Shibuya-AX, Tokyo, Japan" => "7254b738-4147-4298-a6e8-7587780392a7",
		"SHIBUYA-AX, Tōkyō, Japan" => "7254b738-4147-4298-a6e8-7587780392a7",
		"NHK Hall, Tokyo, Japan" => "fa8abb2c-4ca0-4838-b374-9c3c88921c77",
		"NHK HALL, Tōkyō, Japan" => "fa8abb2c-4ca0-4838-b374-9c3c88921c77",
		"Zepp Tokyo, Japan" => "bc1c475b-e265-4b0c-8283-4b3d1d87cf5f",
		"Zepp, Tokyo, Japan" => "bc1c475b-e265-4b0c-8283-4b3d1d87cf5f",
		"Zepp Tokyo, Tokyo, Japan" => "bc1c475b-e265-4b0c-8283-4b3d1d87cf5f",
		"Tokyo Koseinenkin Kaikan, Tokyo, Japan" => "c20359e1-0637-4957-8633-509496de89d9",
		"Tokyo Kōsei Nenkin Kaikan, Tokyo, Japan" => "c20359e1-0637-4957-8633-509496de89d9",
		"Tokyo Dome, Tokyo, Japan" => "9ebc6213-bd3d-40bb-b1d8-cc6d9f9a68fa",
		"Yoyogi National Gymnasium, Tokyo, Japan" => "38c64b31-c3b4-48f4-b840-d2cc2b9de6e7",
		"Shinjuku Koseinenkin Kaikan, Tokyo, Japan" => "c20359e1-0637-4957-8633-509496de89d9",
		"Shinjuku Kouseinenkin Kaikan Hall, Tokyo, Japan" => "c20359e1-0637-4957-8633-509496de89d9",
		"Kosei Nekin Kaiken Hall, Tokyo, Japan" => "c20359e1-0637-4957-8633-509496de89d9",
		"Hibiya Open-Air Concert Hall, Tokyo, Japan" => "afcfbe70-e168-435a-b0fe-3c556d5b5691",
		"Akasaka BLITZ, Tokyo, Japan" => "506f7fca-a300-4826-af0f-3d7787e0073e",
		"AKASAKA BLITZ, Tōkyō, Japan" => "506f7fca-a300-4826-af0f-3d7787e0073e",
		"Club Citta', Tokyo, Japan" => "501f4596-ef30-44d8-8501-9fd38727530a",
		"Club Citta, Tokyo, Japan" => "501f4596-ef30-44d8-8501-9fd38727530a",
		"Shibuya O-EAST, Tōkyō, Japan" => "194cd897-7894-4e5c-9f28-ea48373b20d9",
		"Shibuya O-WEST, Tōkyō, Japan" => "eac5ce60-3280-479e-9a38-66d6d2e4c9ff",
		"渋谷C.C.Lemonホール, Tōkyō, Japan" => "ce02592c-e1ad-4e3f-9382-07dd9e4490c6",
		"Shibuya Public Hall, Tokyo, Japan" => "ce02592c-e1ad-4e3f-9382-07dd9e4490c6",

		"Muse Hall, Osaka, Japan" => "fed4574d-2756-442e-8588-93e7a313c87b",
		"OSAKA MUSE HALL, Japan" => "fed4574d-2756-442e-8588-93e7a313c87b",
		"Osaka-jō Hall, Osaka, Japan" => "50cdb1ed-2084-45b7-8f5d-e2e18c0d370c",
		"Osaka Castle Hall, Osaka, Japan" => "50cdb1ed-2084-45b7-8f5d-e2e18c0d370c",
		"Castle Hall, Osaka, Japan" => "50cdb1ed-2084-45b7-8f5d-e2e18c0d370c",
		"Festival Hall, Osaka, Japan" => "d3203594-47e6-47e2-8a75-8cfef53ffc0c",
		"Ōsaka Festival Hall, Japan" => "d3203594-47e6-47e2-8a75-8cfef53ffc0c",
		"NHK Hall, Osaka, Japan" => "69892d13-041d-4d1a-8187-9f9914197b29",
		"Shinsaibashi Club Quattro, Osaka, Japan" => "27c0378f-0cfa-4920-8870-ea9b9bc5828d",
		"Kosei Nenkin Kaikan, Osaka, Japan" => "751f998a-60ca-4d48-954f-b101d59ad89a",
		"Kousei Nenkin Kaikan, Osaka, Japan" => "751f998a-60ca-4d48-954f-b101d59ad89a",
		"Koseinenkin Hall, Osaka, Japan" => "751f998a-60ca-4d48-954f-b101d59ad89a",
		"Kouseinennkin Kaikan, Osaka, Japan" => "751f998a-60ca-4d48-954f-b101d59ad89a",
		"Kousei Nenkin Kaikan Hall, Osaka, Japan" => "751f998a-60ca-4d48-954f-b101d59ad89a",

		"Yokohama Arena, Yokohama, Japan" => "0ad0262f-5252-4e0d-9a60-e32b8badf659",
		"Yokohama Stadium, Japan" => "6ed7e3dc-1754-49cf-938f-aa4efcd31374",
		"YOKOHAMA BLITZ, Yokohama, Japan" => "48a895f2-1fa9-4ea3-a3dd-98f086fae4db",
		"Yokohama Blitz, Yokohama, Japan" => "48a895f2-1fa9-4ea3-a3dd-98f086fae4db",
		"Pacifico Yokohama, Yokohama, Japan" => "503b5953-3bab-4cdf-b2e4-470e1506440b",

		"Hiroshima Sun Plaza Hall, Hiroshima, Japan" => "229ab714-eb87-43d8-b5eb-559122acaa08",

		"Club Quattro, Nagoya, Japan" => "f8d67bc7-0e5b-417b-9316-c46ca9854a20",

		"Izumity 21, Sendai, Japan" => "90086bad-8dac-4627-a6f4-c83a960b2ded",

		"Saitama Super Arena, Saitama, Japan" => "1e5ec994-f29c-455f-8be8-a1295a7135de",
		"さいたまスーパーアリーナ, Japan" => "1e5ec994-f29c-455f-8be8-a1295a7135de",

		"ZEPP, Fukuoka, Japan" => "dfe668a0-65ae-4e2f-a761-581fd49fe993",
		"the Zepp, Fukuoka, Japan" => "dfe668a0-65ae-4e2f-a761-581fd49fe993",

	);

	return %mapping;
}

1;


Config = {}

Config.Locale = 'sr'

Config.PaymentAccount = 'money'
-- money = cash
-- bank  = bank

Config.Locations = {

    --- city
    {
        Ped = {
            model = 'a_m_m_business_01',
            coords = vec4(110.2076, -1089.5126, 29.3025, 0.6418),
            scenario = 'WORLD_HUMAN_CLIPBOARD'
        },
        VehicleSpawns = {
            vec4(108.4089, -1080.1195, 29.1930, 160.9678),
            vec4(111.9889, -1081.1732, 29.1924, 175.8214)
        },
        Blip = {
            enabled = true,
            coords = vec3(110.7250, -1089.3877, 28.6268),
            sprite = 225,
            color = 2,
            scale = 0.75,
            name = 'Rent A Car'
        }
    },

    --- paleto bay
    {
        Ped = {
            model = 'a_m_m_business_01',
            coords = vec4(-143.5758, 6274.4146, 31.3424, 271.4993),
            scenario = 'WORLD_HUMAN_CLIPBOARD'
        },
        VehicleSpawns = {
            vec4(-138.2678, 6276.8950, 31.3418, 233.4278),
            vec4(-135.4208, 6279.1016, 31.3467, 251.7536)
        },
        Blip = {
            enabled = true,
            coords = vec3(-140.6666, 6274.3188, 31.3383),
            sprite = 225,
            color = 2,
            scale = 0.75,
            name = 'Rent A Car'
        }
    }
}

Config.WarpIntoVehicle = true
Config.SpawnClearRadius = 3.0

---- change description if you use serbian or other language.
Config.Vehicles = {
    cars = {
        { model = 'bison', label = 'Bison', price = 700, description = 'Reliable off-road vehicle.', image = 'images/bison.png' },
        { model = 'futo', label = 'Futo', price = 1000, description = 'Small and agile city car.', image = 'images/futo.png' },
        { model = 'tailgater2', label = 'Audi', price = 1850, description = 'Modern and fast sedan for everyday driving.', image = 'images/tailgater2.png' },
        { model = 'buccaneer', label = 'Buccaneer', price = 1500, description = 'Solid and reliable car.', image = 'images/buccaneer.png' },
        { model = 'huntley', label = 'Huntley S', price = 2200, description = 'Modern SUV ideal for rough terrain.', image = 'images/huntley.png' },
        { model = 'surge', label = 'Surge', price = 1900, description = 'Modern electric car.', image = 'images/surge.png' }
    },
    motorcycles = {
        { model = 'bati', label = 'Pegassi Bati 801', price = 1500, description = 'Sport bike for fast city riding.', image = 'images/bati.png' },
        { model = 'sanchez', label = 'Sanchez', price = 900, description = 'Great motorcycle for city and off-road riding.', image = 'images/sanchez.png' },
        { model = 'faggio', label = 'Pegassi Faggio', price = 400, description = 'Cheap and practical scooter.', image = 'images/faggio.png' }
    }
}

-- Add this item to ox_inventory/data/items.lua

['rent_documents'] = {
    label = 'Rent Documents',
    weight = 10,
    stack = false,
    close = true,
    description = 'Documents for a rented vehicle.',
    client = { export = 'ps_rentacar.useRentPapers' }
},

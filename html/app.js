const app = document.getElementById('app'), vehicleList = document.getElementById('vehicleList');
let vehicles = {}, currentCategory = 'cars', selectedVehicle = null, selectedPayment = 'cash', tr = {};
const nui = (e, d = {}) => fetch(`https://${GetParentResourceName()}/${e}`, { method: 'POST', headers: {'Content-Type':'application/json'}, body: JSON.stringify(d) }).catch(() => {});
const t = (key, fallback) => tr[key] || fallback || key;
const money = v => '$' + Number(v || 0).toLocaleString('en-US');
const price = v => Number(v.price || 0);

function renderVehicles() {
    const list = vehicles[currentCategory] || [];
    document.getElementById('categoryTitle').textContent = currentCategory === 'cars' ? t('cars','Cars') : t('motorcycles','Motorcycles');
    document.getElementById('count').textContent = t('vehicles_count', '%s vehicles').replace('%s', list.length);
    vehicleList.innerHTML = '';
    list.forEach(v => {
        const c = document.createElement('article'); c.className = 'vehicle-card';
        let imagePath = v.image ? `./${v.image.replace(/^\/+/, '').replace(/\.svg$/i, '.png')}` : '';
        c.innerHTML = `<div class="vehicle-image">${imagePath ? `<img src="${imagePath}" alt="${v.label || t('rent_a_car','Vehicle')}" onerror="this.style.display='none'; console.error('PNG not found:', this.src)">` : ''}</div><div class="vehicle-body"><h3>${v.label}</h3><p>${v.description || t('vehicle_available','Vehicle available for rent.')}</p><div class="vehicle-bottom"><div class="price">${money(price(v))}<small>/ ${t('rent','rent')}</small></div><button class="rent-btn">${t('rent','Rent')}</button></div></div>`;
        c.querySelector('.rent-btn').onclick = () => openConfirm(v); vehicleList.appendChild(c);
    });
}
function openConfirm(v) {
    selectedVehicle = v;
    document.getElementById('confirmTitle').textContent = t('rent_vehicle_question','Rent %s?').replace('%s', v.label);
    document.getElementById('confirmDescription').textContent = v.description || '';
    document.getElementById('confirmPrice').textContent = money(price(v));
    selectedPayment = 'cash';
    document.querySelectorAll('.payment').forEach(x => x.classList.toggle('active', x.dataset.payment === 'cash'));
    document.getElementById('confirm').classList.remove('hidden');
}
function closeConfirm() { selectedVehicle = null; document.getElementById('confirm').classList.add('hidden'); }
document.querySelectorAll('.category').forEach(b => b.onclick = () => { document.querySelectorAll('.category').forEach(x => x.classList.remove('active')); b.classList.add('active'); currentCategory = b.dataset.category; renderVehicles(); });
document.getElementById('close').onclick = () => nui('close');
document.getElementById('cancel').onclick = () => closeConfirm();
document.querySelectorAll('.payment').forEach(b => b.onclick = () => { selectedPayment = b.dataset.payment; document.querySelectorAll('.payment').forEach(x => x.classList.remove('active')); b.classList.add('active'); });
document.getElementById('confirmRent').onclick = () => { if (!selectedVehicle) return; const b = document.getElementById('confirmRent'); b.disabled = true; nui('rentVehicle', {model:selectedVehicle.model, payment:selectedPayment}); setTimeout(() => b.disabled = false, 1500); };
window.addEventListener('message', e => { const d = e.data || {}; if (d.action === 'open') { vehicles = d.vehicles || {}; tr = d.translations || {}; app.classList.remove('hidden'); renderStaticText(); renderVehicles(); } if (d.action === 'close') { closeConfirm(); app.classList.add('hidden'); } });
function renderStaticText() {
    document.querySelector('.eyebrow').textContent = t('city_transport','CITY TRANSPORT');
    document.querySelector('header h1').innerHTML = `${t('rent_a_car','Rent')} <span>A Car</span>`;
    document.querySelector('header p').textContent = t('choose_category_vehicle','Choose a category and vehicle.');
    const cats = document.querySelectorAll('.category');
    if (cats[0]) { cats[0].querySelector('strong').textContent = t('cars','Cars'); cats[0].querySelector('small').textContent = t('cars_desc','City, sports and off-road vehicles'); }
    if (cats[1]) { cats[1].querySelector('strong').textContent = t('motorcycles','Motorcycles'); cats[1].querySelector('small').textContent = t('motorcycles_desc','Motorcycles & scooters'); }
    document.querySelector('.rental-info span').textContent = t('rental_until_restart','Rental is valid until the next server restart');
    document.querySelector('.payment-title').textContent = t('payment_method','PAYMENT METHOD');
    const p = document.querySelectorAll('.payment');
    if (p[0]) { p[0].querySelector('strong').textContent = t('cash','Cash'); p[0].querySelector('small').textContent = t('cash_desc','Cash payment'); }
    if (p[1]) { p[1].querySelector('strong').textContent = t('card','Card'); p[1].querySelector('small').textContent = t('card_desc','Bank account'); }
    document.getElementById('cancel').textContent = t('cancel','Cancel'); document.getElementById('confirmRent').textContent = t('rent','Rent');
}
document.addEventListener('keydown', e => { if (e.key !== 'Escape') return; const confirm = document.getElementById('confirm'); if (!confirm.classList.contains('hidden')) closeConfirm(); else nui('close'); });

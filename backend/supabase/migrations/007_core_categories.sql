insert into public.categories (name,slug,description,icon,type,sort_order,status)
values
('Immobilier','immobilier','Locations, ventes et biens professionnels','home','marketplace',10,'active'),
('Hébergement','hebergement','Hôtels, appartements, maisons d’hôtes et résidences','hotel','marketplace',20,'active'),
('Restaurants','restaurants','Restaurants, cafés, snacks et restauration','utensils','marketplace',30,'active'),
('Commerces','commerces','Boutiques, alimentation et commerce local','shopping-bag','marketplace',40,'active'),
('Services','services','Professionnels, artisans et services du quotidien','wrench','marketplace',50,'active'),
('Mobilité','mobilite','Location de véhicules, taxis et mobilité touristique','car','marketplace',60,'active'),
('Loisirs','loisirs','Activités, excursions, sport et divertissement','sparkles','marketplace',70,'active')
on conflict (slug) do update set name=excluded.name,description=excluded.description,icon=excluded.icon,type=excluded.type,sort_order=excluded.sort_order,status=excluded.status;
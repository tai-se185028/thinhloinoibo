insert into public.categories(name,description) values
('Thùng carton','Bao bì carton các loại'),('Túi giấy','Túi giấy kraft'),('Túi nhựa','Túi PE, zipper và niêm phong'),('Phụ kiện','Băng keo và dây đai') on conflict do nothing;
insert into public.warehouses(code,name,address) values ('KHO-HCM','Kho trung tâm TP.HCM','125 Nguyễn Văn Linh, Quận 7, TP.HCM') on conflict do nothing;
insert into public.business_settings(business_name,address,phone,email,bank_name,bank_account_number,bank_account_holder)
select 'CÔNG TY TNHH BAO BÌ PACKFLOW','125 Nguyễn Văn Linh, Quận 7, TP.HCM','028 3765 8899','kho@packflow.vn','Vietcombank','1028896688','CÔNG TY TNHH BAO BÌ PACKFLOW'
where not exists(select 1 from public.business_settings);

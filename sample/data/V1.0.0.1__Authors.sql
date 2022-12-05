
-- The 'On Conflict Do Nothing' means that only new rows are inserted.
-- While you are developing just delete the schema version row and re-run
-- as you add test data.  Once it is merged it will detect signature changes
-- if someone tries to alter the script after it is run on a live DB.

Insert Into author (first_name, last_name)
Values ('Mercedes', 'Lackey'),
	('Ursala', 'Vernon'),
	('Terry', 'Pratchet'),
	('Seanan', 'McGuire'),
	('Neil', 'Gaimon'),
	('Lois', 'Bujold'),
	('Ian', 'Banks'),
	('Ilona', 'Andrews')
On Conflict Do Nothing;




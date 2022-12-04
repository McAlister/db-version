

Insert Into book (title, author_id)
Select 'Falling Free', id From author where last_name = 'Bujold' and first_name = 'Lois'
On Conflict Do Nothing;


/* Netflix data cleaning and analysis project */
/* 1. Handling foreign values
* Drop the old and create new table
because there are foreign values and
we also want to set constraints
*/
select * from netflix_raw order by title
drop table if exists netflix_raw;
CREATE TABLE netflix_raw (
	show_id VARCHAR(10) null,
	"type" VARCHAR(10) null,
	title VARCHAR(200) null,
	director VARCHAR(400) null,
	"cast" VARCHAR(1500) null,
	country VARCHAR(300) null,
	date_added VARCHAR(50) null,
	release_year smallint null,
	rating VARCHAR(50) null,
	duration VARCHAR(50) null,
	listed_in VARCHAR(200) null,
	description VARCHAR(500) null
	);
/* Check if the foreign values shows
*/
select * from netflix_raw
WHERE show_id= 's5023';
/* 2. Handle duplicate values
*/
select show_id, COUNT(*)
from netflix_raw
group by show_id
having count(*)>1;
-- no duplicate values in show_id so we will set PK
ALTER TABLE netflix_raw
ADD CONSTRAINT pk_show_id PRIMARY KEY (show_id);
-- but there might be duplicates in title
-- identify duplicates, including upper and lower case
select * from netflix_raw 
where upper(title) in (
select upper(title)
from netflix_raw
group by upper(title)
having count(*)>1
)
order by title;
-- we see Esperando and Love in a Puff are duplicates
/* if we want to identify duplicates using
both title and type
*/
select * from netflix_raw 
where concat(upper(title), type) in (
select concat(upper(title), type)
from netflix_raw
group by upper(title), type
having count(*)>1
)
order by title;
-- remove duplicates
with cte as (
select *,
ROW_NUMBER() OVER(partition by upper(title), type order by show_id) as rn
from netflix_raw nr )
select *
from cte
where rn = 1;
select * from netflix;

-- 3. Splitting genre into new table
insert into netflix_genre (show_id, genre)
select show_id, trim(value) as genre
from netflix_raw, regexp_split_to_table(listed_in, ',') as value;

select * from netflix_raw;

-- Insert missing values in country and duration columns
insert into netflix_country (show_id, country)
select nr.show_id, m.country 
from netflix_raw nr
inner join (
  select director, country
  from netflix_country nc
  inner join netflix_directors nd on nc.show_id = nd.show_id
  group by director, country
) m on nr.director = m.director
where nr.country is null;

select * from netflix_raw where director = 'Ahishor Solomon';

select director, country
from netflix_country nc
inner join netflix_directors nd on nc.show_id = nd.show_id
group by director, country;

-- Check for rows with NULL duration
select * from netflix_raw where duration is null;

-- Populate missing values with 'not_available' and drop columns
-- Netflix data analysis

--  Count movies and TV shows for each director who created both
select nd.director,
  COUNT(distinct case when n.type = 'Movie' then n.show_id end) as no_of_movies,
  COUNT(distinct case when n.type = 'TV Show' then n.show_id end) as no_of_tvshow
from netflix n
inner join netflix_directors nd on n.show_id = nd.show_id
group by nd.director
having COUNT(distinct n.type) > 1;

--  Country with the highest number of comedy movies
select nc.country, COUNT(distinct ng.show_id) as no_of_movies
from netflix_genre ng
inner join netflix_country nc on ng.show_id = nc.show_id
inner join netflix n on ng.show_id = n.show_id
where ng.genre = 'Comedies' and n.type = 'Movie'
group by nc.country
order by no_of_movies desc
limit 1;

-- Director with the most movies added to Netflix per year
with cte as (
  select nd.director, EXTRACT(YEAR from date_added) as date_year, count(n.show_id) as no_of_movies
  from netflix n
  inner join netflix_directors nd on n.show_id = nd.show_id
  where n.type = 'Movie'
  group by nd.director, EXTRACT(YEAR from date_added)
),
cte2 as (
  select *, ROW_NUMBER() over(partition by date_year order by no_of_movies desc, director) as rn
  from cte
)
select * from cte2 where rn = 1;

-- Average duration of movies in each genre
select ng.genre, avg(cast(REPLACE(duration, ' min', '') AS int)) as avg_duration
from netflix n
inner join netflix_genre ng on n.show_id = ng.show_id
where n.type = 'Movie'
group by ng.genre;

-- Directors who directed both horror and comedy movies
select nd.director,
  count(distinct case when ng.genre = 'Comedies' then n.show_id end) as no_of_comedy,
  count(distinct case when ng.genre = 'Horror Movies' then n.show_id end) as no_of_horror
from netflix n
inner join netflix_genre ng on n.show_id = ng.show_id
inner join netflix_directors nd on n.show_id = nd.show_id
where n.type = 'Movie' and ng.genre in ('Comedies', 'Horror Movies')
group by nd.director
having COUNT(distinct ng.genre) = 2;

-- Query to display genres for a specific director
select * from netflix_genre
where show_id in (
  select show_id from netflix_directors where director = 'Steve Brill'
)
order by genre;


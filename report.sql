
---------------------------------------------------------------------------------------------------
-- Part I
---------------------------------------------------------------------------------------------------

-- How many unique companies we are dealing with?
SELECT COUNT(DISTINCT companyAlias) as Companies
FROM churn;
-- 37

-- What about the total number of employees taking part in the voting ?
-- (employees with negative IDs are discarded)
SELECT SUM(Num_empl)
FROM (SELECT companyAlias, COUNT(employee) as Num_empl
      FROM churn
      WHERE employee > 0 
      GROUP by 1);
-- There are 4418.  

-- Were all these employees unique? 
SELECT SUM(Num_empl)
FROM (SELECT companyAlias, COUNT(DISTINCT employee) as Num_empl
      FROM churn
      WHERE employee > 0
      GROUP by 1);
-- No. The total number of unique employees (voters) is 4377 suggesting that there are
-- 41 duplicates.  

-- Let's check who are these people	
SELECT companyAlias, employee, COUNT(*)
FROM churn
WHERE employee > 0
GROUP BY 1, 2 
HAVING COUNT(*)>1
ORDER BY 1,2,3 ASC;
-- 36 employees are listed twice, and one employee has 6 entries. 
-- All duplicates are not considered in the further analysis.  


-- How many unique employees quit (what is the churn rate) ?
SELECT SUM(Num_empl)
FROM (SELECT companyAlias, COUNT(DISTINCT employee) as Num_empl
      FROM churn
      WHERE employee > 0 and stillExists = 'false'
      GROUP by 1);
-- 707, the corresponding churn rate is 16% 



-- It is interesting to know whether the quit and staying employees voted differently?
--
-- Let's first compute the total numbers of voters in each employee category and company
WITH tmp
AS	(
	SELECT companyAlias, employee, 
	       CASE WHEN stillExists='false' THEN 1 ELSE 0 END AS EQuit,
	       CASE WHEN stillExists='true'  THEN 1 ELSE 0 END AS EStay	  
	FROM churn 
	WHERE employee > 0 
	GROUP BY 1, 2
	)	
SELECT companyAlias, 
       SUM(EQuit) as EmplQuit, 
       SUM(EStay) as EmplStay
FROM tmp 
GROUP BY 1;
--HAVING EmplQuit >= 10 AND EmplStay >=10;
/*
The results show that many companies had only a very few voters.
Even more severe is the fact that many companies do not have any voting data 
for the churn employees. Why? Did churn employees avoid voting? 
If yes, this could be used for prediction of the employee turnover.  

To avoid skewing data, the further analysis will be done by considering only those companies 
that have sufficient numbers of voters (say, >=10 ) in both categories of employees. 
There are 10 such companies.

Figure 'Empl_status_by_company.png' shows the relative amount of different types of employees
in each selected company. Except of two cases, the staying employees represent the majority.   
*/

-- What are the mean votes given by different employees in the selected companies? 
WITH tmp
AS	(
	SELECT companyAlias, employee, 
	       CASE WHEN stillExists='false' THEN 1 ELSE 0 END AS EQuit,
	       CASE WHEN stillExists='true'  THEN 1 ELSE 0 END AS EStay	  
	FROM churn 
	WHERE employee > 0 
	GROUP BY 1, 2
	),
tmp2
AS	(	
	SELECT companyAlias, 
	       SUM(EQuit) as EmplQuit, 
	       SUM(EStay) as EmplStay
	FROM tmp 
	GROUP BY 1
	HAVING EmplQuit >= 10 AND EmplStay >=10
	)
SELECT t2.companyAlias, 
       AVG(CASE WHEN Equit =1 THEN v.vote ELSE NULL END) as MeanVoteQuit, 
       AVG(CASE WHEN EStay =1 THEN v.vote ELSE NULL END) as MeanVoteStay
FROM tmp2 t2
JOIN tmp t1 USING (companyAlias)
JOIN votes v on t2.companyAlias=v.companyAlias and t1.employee=v.employee
GROUP BY 1;
/*
As seen from figure 'MeanVotes_by_company.png', in overal, the staying employees gave a higher 
vote than the churn ones. However, the vote difference is remarkable in a few cases only. 
The mean vote of the quit employees is 2.67. The staying employees gave 2.91, on average. 
Let's look at the vote destributions now.
*/ 

-- The following query yields distributions of votes by company and employee's category 
WITH tmp
AS	(
	SELECT companyAlias, employee, 
	       CASE WHEN stillExists='false' THEN 1 ELSE 0 END AS EQuit,
	       CASE WHEN stillExists='true'  THEN 1 ELSE 0 END AS EStay	  
	FROM churn 
	WHERE employee > 0 
	GROUP BY 1, 2
	),
tmp2
AS	(	
	SELECT companyAlias, 
               SUM(EQuit) as EmplQuit, 
	       SUM(EStay) as EmplStay
	FROM tmp 
	GROUP BY 1
	HAVING EmplQuit >= 10 AND EmplStay >=10
	),
tmp3
AS	(
	SELECT t2.companyAlias, v.vote, SUM(EQuit) as NQuit, SUM(EStay) as NStay
	FROM tmp2 t2
	JOIN tmp t1 USING (companyAlias)
	JOIN votes v on t2.companyAlias=v.companyAlias and t1.employee=v.employee
	GROUP BY 1,2
	)
SELECT companyAlias, vote, NQuit, NStay, 
       100.*NQuit/(SUM(NQuit) OVER ( PARTITION BY companyAlias)) as PctVQuit,
       100.*NStay/(SUM(NStay) OVER ( PARTITION BY companyAlias)) as PctVStay
FROM tmp3;

-- Finally, let's find the vote distributions for both types of employees averaged over all companies
WITH tmp
AS	(
	SELECT companyAlias, employee, 
	       CASE WHEN stillExists='false' THEN 1 ELSE 0 END AS EQuit,
	       CASE WHEN stillExists='true'  THEN 1 ELSE 0 END AS EStay	  
	FROM churn 
	WHERE employee > 0 
	GROUP BY 1, 2
	),
tmp2
AS	(	
	SELECT companyAlias, 
	       SUM(EQuit) as EmplQuit, 
	       SUM(EStay) as EmplStay
	FROM tmp 
	GROUP BY 1
	HAVING EmplQuit >= 10 AND EmplStay >=10
	),
tmp3
AS	(
	SELECT t2.companyAlias, v.vote, SUM(EQuit) as NQuit, SUM(EStay) as NStay
	FROM tmp2 t2
	JOIN tmp t1 USING (companyAlias)
	JOIN votes v on t2.companyAlias=v.companyAlias and t1.employee=v.employee
	GROUP BY 1,2
	),
tmp4
AS	(
	SELECT companyAlias, vote, 
               100.*NQuit/(SUM(NQuit) OVER ( PARTITION BY companyAlias)) as PctVQuit,
	       100.*NStay/(SUM(NStay) OVER ( PARTITION BY companyAlias)) as PctVStay
	FROM tmp3
	)
SELECT vote, AVG(PctVQuit) as 'Mean_VPct_Quit (%)', Avg(PctVStay) as 'Mean_VPct_Stay (%)'
FROM tmp4
GROUP BY 1;
/*
   As seen from figure 'Vote_Distr_by_EmplCat.png', the icon '3-Good' was the favorite choice of both quit 
and staying employees. This vote has scored ~42.5%. 
   The happiness icons '1-Pretty Bad' and '2-So So' were about 3 times less popular, thereby the churn 
employees chose these icons a bit more frequently (by 2-3%). 
   The choice '4-Great' deserves a special attention since the difference between the employee categories 
is the most remarkable here. The quit employee were definetely much more reluctant (by 6.5%) to indicate this 
happiness level.   
*/  

---------------------------------------------------------------------------------------------------
--Part II
---------------------------------------------------------------------------------------------------

/*
After indicating their feeling by touching one of the four icons, the employees are redirected to 
the second screen. Here, they can optionally provide their (anonymized (?)) comments, suggestions or 
complains which receive likes or dislikes from other colleagues. 
The data regarding this second page is collected in the table 'comments_clean_anonimized'  
*/
 
-- How many unique employees gave a comment (for all 37 companies)?
SELECT SUM(Num_empl)
FROM (SELECT companyAlias, COUNT(DISTINCT employee) as Num_empl
      FROM comments_clean_anonimized
      WHERE employee > 0 
      GROUP by 1);
-- There were 2881 such employees. This corresponds to 65.6% of the employees (4377) which took part 
-- in the voting.  

-- The following query provides an important insight into the willingness of the churn and staying 
-- employees to comment on their happiness level 
-- (only 10 companies possessing sufficient numbers of voters are considered) 
SELECT ch.companyAlias,
       COUNT(DISTINCT CASE WHEN stillExists='false' THEN ch.employee  ELSE NULL END) as NVQuit,
       COUNT(DISTINCT CASE WHEN stillExists='true'  THEN ch.employee  ELSE NULL END) as NVStay,
       COUNT(DISTINCT CASE WHEN stillExists='false' THEN cca.employee ELSE NULL END) as NCQuit,
       COUNT(DISTINCT CASE WHEN stillExists='true'  THEN cca.employee ELSE NULL END) as NCStay,
  100.*COUNT(DISTINCT CASE WHEN stillExists='false' THEN cca.employee ELSE NULL END) / 
       COUNT(DISTINCT CASE WHEN stillExists='false' THEN ch.employee  ELSE NULL END) as 'V_to_Com_Quit(%)',
  100.*COUNT(DISTINCT CASE WHEN stillExists='true'  THEN cca.employee ELSE NULL END) / 
       COUNT(DISTINCT CASE WHEN stillExists='true'  THEN ch.employee  ELSE NULL END) as 'V_to_Com_Stay(%)'
FROM churn ch
LEFT JOIN comments_clean_anonimized cca ON ch.companyAlias= cca.companyAlias AND ch.employee=cca.employee
WHERE ch.employee > 0 AND numVotes > 0
  AND ch.companyAlias in (
	 '5370af43e4b0cff95558c12a', '53a2dd43e4b01cc02f1e9011', 
	 '54e52607e4b01191dc064966', '5641f96713664c000332c8cd',
	 '56aec740f1ef260003e307d6', '56fd2b64f41c670003f643c8',
 	 '5742d699f839a10003a407d2', '574c423856b6300003009953',
	 '57dd2d6a4018d9000339ca43', '58a728a0e75bda00042a3468')
GROUP BY ch.companyAlias;
/*
Importantly, as seen from figure 'Percentage_Vote_to_Comment.png', the staying employees were much 
more prone to comment than the churn colleagues. Approximately 75-80% of the former gave a comment on
their happiness level after voting. 

The corresponding percentages are much lower in the case of the churn voters. In two companies they are 
only 5 and 10%. There are even two companies where none of the churn employees wrote a single line! 
*/

-- How many comments were posted ?
SELECT companyAlias, employee, commentId, COUNT(*)
FROM comments_clean_anonimized cca
WHERE employee > 0
GROUP BY 1,2,3
ORDER by 4 DESC;
-- There are 38993 unique comment IDs. However, 38336 of them are duplicated. 
-- All duplicates are discarded in the next steps. 

/*
As discovered above, the churn employees were much less eager to comment on their vote and happiness 
level. For those people (quit and staying) who nonetheless commented, what was the reaction of 
colleagues on the comments posted? Did the colleagues liked or disliked the comments?

The following query evaluates the response of colleagues on the comments given by the quit and staying
employees. The numbers of likes and dislikes per comment are computed. Only seven companies out of 
the above ten were considered. The rest companies had either none or just a single comment
from the quit employees.
*/
WITH tmp
AS	(
	SELECT ch.companyAlias, ch.employee, stillExists, commentId, likes, dislikes
	FROM churn ch
	JOIN comments_clean_anonimized cca ON ch.companyAlias= cca.companyAlias AND ch.employee=cca.employee
	WHERE ch.employee > 0 AND numVotes > 0
	  AND ch.companyAlias in (
		'5370af43e4b0cff95558c12a', '53a2dd43e4b01cc02f1e9011', 
		'54e52607e4b01191dc064966', '5641f96713664c000332c8cd',
		'56aec740f1ef260003e307d6', '56fd2b64f41c670003f643c8',
		'5742d699f839a10003a407d2')
	GROUP by commentId)
SELECT stillExists,
   1.0*SUM(likes)/COUNT(commentId) as Likes_per_Comm,
   1.0*SUM(dislikes)/COUNT(commentId) as Dislikes_per_Comm,
   1.0*(SUM(likes)+SUM(dislikes))/COUNT(commentId) as Response_per_Comm
FROM tmp
GROUP BY stillExists;
/*
The churn and staying employees got similar amounts of feedback for their comments: 9.62 vs. 9.81 
responses per comment, respectively. However, the feedback structure was different, as seen from 
figure 'Response_per_Comment.png'. The staying colleagues were more likeable, namely they received 
more likes and less dislikes per comment than the churn ones,  
likes per comment     dislikes per comment
   Quit  Stay         Quit  Stay         
   7.68	  8.31	      1.9   1.49
The feedback structure for each company is represented in figures 
'Likes_per_comment.png' and 'Dislikes_per_comment.png'
*/

---------------------------------------------------------------------------------------------------
--Part III
---------------------------------------------------------------------------------------------------

/*
After voting and giving an optional comment, the employees are redirected to the last page where they can
read all comments and interact with them. The corresponding data is given in the table 'commentInteractions'
*/  

-- How many unique employees interacted with comments?
SELECT SUM(Num_empl)
FROM (SELECT companyAlias, COUNT(DISTINCT employee) as Num_empl
      FROM commentInteractions
      WHERE employee > 0 
      GROUP BY 1);
-- there were 3147 which is 72% of those (4377) participating in the voting.

-- The following query computes the churn percentages (vote_to_reaction) for different types of
-- employees and companies
SELECT ch.companyAlias,
       COUNT(DISTINCT CASE WHEN stillExists='false' THEN ch.employee  ELSE NULL END) as NVQuit,
       COUNT(DISTINCT CASE WHEN stillExists='true'  THEN ch.employee  ELSE NULL END) as NVStay,
       COUNT(DISTINCT CASE WHEN stillExists='false' THEN ci.employee ELSE NULL END) as NRQuit,
       COUNT(DISTINCT CASE WHEN stillExists='true'  THEN ci.employee ELSE NULL END) as NRStay,
  100.*COUNT(DISTINCT CASE WHEN stillExists='false' THEN ci.employee ELSE NULL END) / 
       COUNT(DISTINCT CASE WHEN stillExists='false' THEN ch.employee  ELSE NULL END) as 'V_to_R_Quit(%)',
  100.*COUNT(DISTINCT CASE WHEN stillExists='true'  THEN ci.employee ELSE NULL END) / 
       COUNT(DISTINCT CASE WHEN stillExists='true'  THEN ch.employee  ELSE NULL END) as 'V_to_R_Stay(%)'
FROM churn ch
LEFT JOIN commentInteractions ci ON ch.companyAlias= ci.companyAlias AND ch.employee=ci.employee
WHERE ch.employee > 0 AND numVotes > 0
  AND ch.companyAlias in (
	 '5370af43e4b0cff95558c12a', '53a2dd43e4b01cc02f1e9011', 
	 '54e52607e4b01191dc064966','5641f96713664c000332c8cd',
	 '56aec740f1ef260003e307d6','56fd2b64f41c670003f643c8',
 	 '5742d699f839a10003a407d2','574c423856b6300003009953',
	 '57dd2d6a4018d9000339ca43','58a728a0e75bda00042a3468')
GROUP BY ch.companyAlias;
/*
The "vote_to reaction" churn (see figure 'Vote_to_Reaction.png') exhibits a similar trend as 
the "vote_to_comment" one. Namely, the staying employees were much more active in giving their 
feedback. 

As before, there are two companies where none of the churn voters interacted with comments, 
and one company possessing only one such person. These three companies are deleted. 
 */
 
-- How many unique comments are there ? Any duplicates?
SELECT COUNT(DISTINCT commentId)
FROM commentInteractions
WHERE employee >0 
  AND companyAlias in (
	 '5370af43e4b0cff95558c12a', '53a2dd43e4b01cc02f1e9011', 
	 '54e52607e4b01191dc064966', '5641f96713664c000332c8cd',
	 '56aec740f1ef260003e307d6', '56fd2b64f41c670003f643c8',
 	 '5742d699f839a10003a407d2');
	 
SELECT companyAlias, employee, commentId, COUNT(*)
FROM commentInteractions
WHERE employee>0
GROUP BY 1,2,3
ORDER BY 4 DESC;
-- There are 20645 unique comments and 8 of them have duplicates (discarded below)

/* The following query provides important statistic for the above-selected seven companies
-- the total number of employees who interacted with comments
-- the total amount of feedback, including the percentages of likes and dislikes
-- the feedback given by an employee
all results have been obtained for the quit and staying employees 
*/
WITH tmp
AS	(
	SELECT ch.companyAlias, ch.employee, stillExists, commentId, liked, disliked
	FROM churn ch
	JOIN commentInteractions ci ON ch.companyAlias= ci.companyAlias AND ch.employee=ci.employee
	WHERE ch.employee > 0 AND numVotes > 0
	  AND ch.companyAlias in (
		'5370af43e4b0cff95558c12a', '53a2dd43e4b01cc02f1e9011', 
		'54e52607e4b01191dc064966', '5641f96713664c000332c8cd',
		'56aec740f1ef260003e307d6', '56fd2b64f41c670003f643c8',
		'5742d699f839a10003a407d2')
	GROUP by ch.companyAlias, ch.employee, commentId)
SELECT stillExists, 
       SUM(CntL) as NL, 
       SUM(CntDL) as NDL, 
       SUM(CntL) + SUM(CntDL) as N_Tot,
       SUM(CntE) as NEmp,
       SUM(CntL)/SUM(CntE) as L_by_E, 
       SUM(CntDL)/SUM(CntE) as DL_by_E,
  100.*SUM(CntL)/(SUM(CntL)+SUM(CntDL)) as 'pct_L (%)',
  100.*SUM(CntDL)/(SUM(CntL)+SUM(CntDL)) as 'pct_DL (%)'
FROM (SELECT companyAlias, stillExists, 
             COUNT(DISTINCT employee) as CntE,
             COUNT(CASE WHEN liked='true'    THEN commentId ELSE NULL END) as CntL,
             COUNT(CASE WHEN disliked='true' THEN commentId ELSE NULL END) as CntDL
      FROM tmp
      GROUP BY 1,2)
GROUP by 1;
/*
As seen from the results (represented also in figure 'Response_by_Employee.png'), 
the staying employees were more engaged in responding on the comments of others. 
On average, a staying employee interacted with 165 comments (liked 139, disliked 26) 
while a churn employee with 146 only (liked 122, disliked 24). 
The percentages of likes (83-84%) and dislikes (16-17%) are nearly the same in each 
category of employees
*/  

---------------------------------------------------------------------------------------------------
-- Conclusions
---------------------------------------------------------------------------------------------------

Based on the above analysis the following conclusions can be drawn about the churn and staying employees:

1. The churn employees seem to be less prone to participate in the voting 
(15 of 37 companies have no voting data for such colleagues)

2. The churn employees are on average less happy and give a lower vote (according to self-reporting).
They more often (2-3%) choose the icons 'Bad' and 'So-so' and less often (6%) 'Great' than the staying employees.

3. The staying employees like to provide a comment on their votes and react on 
comments of others (80% of such voters do so). The churn colleagues are much more restrained.  

4. The staying employees are more likeable. Their comments receive more likes (by 8%) and less dislikes than
the comments of the churn employees.

5. The staying employees are more active in interacting with comments. On average, a single staying employee 
provides a feedback for 165 comments (83.5% likes), while a churn employee for 146 only (83.5% likes).

Unfortunatelly, the comments are not available. Their sentiment analysis would be very useful for  
predicting the employees turnover.

 
      

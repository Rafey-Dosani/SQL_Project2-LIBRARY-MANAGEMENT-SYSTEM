--LIBRARY MANAGEMENT SYSTEM QUERY 2
SELECT * FROM BOOKS
SELECT * FROM employee
SELECT * FROM member
SELECT * FROM branch
SELECT * FROM issued_status
SELECT * FROM return_status

--Task 13: Identify Members with Overdue Books
--Write a query to identify members who have overdue books (assume a 30-day return period). Display the member's_id, member's name, book title, issue date, and days overdue.

--TABLE REQ: MEMBER, BOOK, ISSUED_STATUS

SELECT m.member_id,
	   m.member_name,
	   b.book_title,
	   ist.issued_date,
	   CURRENT_DATE-ist.issued_date as Over_Due

FROM issued_status as ist
JOIN 
member as m 
ON ist.issued_member_id=m.member_id
JOIN 
books as b 
ON ist.issued_book_isbn=b.isbn
LEFT JOIN 
return_status as rs 
ON ist.issued_id=rs.issued_id
WHERE 
	rs.return_id IS NULL
	AND 
	(CURRENT_DATE-ist.issued_date )>30




--Task 14: Update Book Status on Return
--Write a query to update the status of books in the books table to "Yes" when they are returned (based on entries in the return_status table).

CREATE OR REPLACE PROCEDURE add_return_record(p_return_id VARCHAR(20), p_issued_id VARCHAR(20), p_book_quality VARCHAR(20))
LANGUAGE plpgsql
AS $$

DECLARE 
	v_isbn VARCHAR(25);
BEGIN 
	--1. INSERT INTO RETRUN TABLE
	--2. GET BOOK ISBN AND NAME 
	--3. UPDATE THE STATUS TO YES(AVAILABLE) IN BOOK TABLE 

		INSERT INTO return_status(return_id, issued_id,return_date,book_quality)
		VALUES(p_return_id,p_issued_id,CURRENT_DATE,p_book_quality);

		SELECT issued_book_isbn 
		INTO 
		v_isbn
		FROM issued_status
		WHERE issued_id=p_issued_id;
		
		UPDATE books 
		SET status='yes'
		WHERE isbn= v_isbn ;

		RAISE NOTICE 'THANK YOU ';	
END; 
$$


CALL add_return_record('124124', 'IS114' ,'GOOD' );

SELECT * FROM BOOKS WHERE ISBN='978-0-19-280551-1'




--Task 15: Branch Performance Report
--Create a query that generates a performance report for each branch, showing the number of books issued, the number of books returned, and the total revenue generated from book rentals.
--TABLES REQ : BRANCH, ISSUED_STATUS, RETURN_STATUS, BOOKS

CREATE TABLE  branch_report
AS
SELECT 
b.branch_id,
b.manager_id,
COUNT(ist.issued_id),
COUNT(rs.return_id),
SUM(bk.rental_price) as total_revenue

FROM
branch as b
JOIN 
employee as e
ON b.branch_id=e.branch_id
JOIN 
issued_status as ist 
ON e.emp_id = ist.issued_emp_id
LEFT JOIN 
return_status as rs
ON ist.issued_id=rs.issued_id
JOIN 
books as bk 
ON ist.issued_book_isbn=bk.isbn
GROUP BY 1


--Task 16: CTAS: Create a Table of Active Members
--Use the CREATE TABLE AS (CTAS) statement to create a new table active_members containing members who have issued at least one book in the last 2 months.

CREATE TABLE active_member AS 
SELECT * FROM 
member as m
JOIN 
issued_status as ist 
ON ist.issued_member_id=m.member_id
WHERE ist.issued_date>=Current_date - INTERVAL '2 month'


--Task 17: Find Employees with the Most Book Issues Processed
--Write a query to find the top 3 employees who have processed the most book issues. Display the employee name, number of books processed, and their branch.

SELECT 
    e.emp_name,
    b.*,
    COUNT(ist.issued_id) as no_book_issued
FROM issued_status as ist
JOIN
employee as e
ON e.emp_id = ist.issued_emp_id
JOIN
branch as b
ON e.branch_id = b.branch_id
GROUP BY 1, 2


--Task 18: Identify Members Issuing High-Risk Books
--Write a query to identify members who have issued books more than twice with the status "damaged" in the books table. Display the member name, book title, and the number of times they've issued damaged books.


SELECT 
	  m.member_name,
   	 b.book_title AS book_title,
    COUNT(*) AS damaged_issue_count
FROM 
member as m 
jOIN 
issued_status as ist 
ON m.member_id=ist.issued_member_id
JOIN 
return_status as rs 
ON  ist.issued_id=rs.issued_id
JOIN 
books b ON ist.issued_book_isbn = b.isbn


WHERE rs.book_quality='Damaged'
GROUP BY 1 ,2
HAVING 
    COUNT(*) > 2;

--Task 19: Stored Procedure Objective: Create a stored procedure to manage the status of books in a library system. Description: Write a stored procedure that updates the status of a book in the library based on its issuance. The procedure should function as follows: The stored procedure should take the book_id as an input parameter. The procedure should first check if the book is available (status = 'yes'). If the book is available, it should be issued, and the status in the books table should be updated to 'no'. If the book is not available (status = 'no'), the procedure should return an error message indicating that the book is currently not available. SELECT * FROM BOOKS

CREATE OR REPLACE PROCEDURE check_book(p_book_isbn VARCHAR(20))
LANGUAGE plpgsql
AS $$
DECLARE
    v_status VARCHAR(5);
BEGIN
    -- Fetch the book status
    SELECT status INTO v_status
    FROM books
    WHERE isbn = p_book_isbn;

    -- Check if book exists
    IF v_status IS NULL THEN
        RAISE NOTICE 'No book found with ISBN: %', p_book_isbn;
        RETURN;
    END IF;

    -- Main logic
    IF v_status = 'yes' THEN
        UPDATE books
        SET status = 'no'
        WHERE isbn = p_book_isbn;
        RAISE NOTICE 'Book with ISBN % has been issued successfully.', p_book_isbn;

    ELSIF v_status = 'no' THEN
        RAISE NOTICE 'Sorry, the book with ISBN % is already issued.', p_book_isbn;
    END IF;
END;
$$;


CALL check_book('978-0-553-29698-2')









--Task 20: Create Table As Select (CTAS) Objective: Create a CTAS (Create Table As Select) query to identify overdue books and calculate fines.

--Description: Write a CTAS query to create a new table that lists each member and the books they have issued but not returned within 30 days. The table should include: The number of overdue books. The total fines, with each day's fine calculated at $0.50. The number of books issued by each member. The resulting table should show: Member ID Number of overdue books Total fines
SELECT * FROM BOOKS

CREATE TABLE overdue_fines AS
SELECT 
    m.member_id,
    COUNT(*) FILTER (WHERE (r.return_id IS NULL AND CURRENT_DATE > i.issued_date + INTERVAL '30 days')
                     OR (r.return_id IS NOT NULL AND r.return_date > i.issued_date + INTERVAL '30 days')
                    ) AS overdue_books,
    SUM(
        CASE
            WHEN r.return_id IS NULL AND CURRENT_DATE > i.issued_date + INTERVAL '30 days'
                THEN (EXTRACT(DAY FROM (CURRENT_DATE - (i.issued_date + INTERVAL '30 days'))) * 0.50)
            WHEN r.return_id IS NOT NULL AND r.return_date > i.issued_date + INTERVAL '30 days'
                THEN (EXTRACT(DAY FROM (r.return_date - (i.issued_date + INTERVAL '30 days'))) * 0.50)
            ELSE 0
        END
    ) AS total_fine,
    COUNT(i.issued_id) AS total_books_issued
FROM 
    member m
JOIN 
    issued_status i ON m.member_id = i.issued_member_id
LEFT JOIN 
    return_status r ON i.issued_id = r.issued_id
GROUP BY 
    m.member_id;
SELECT * FROM overdue_fines












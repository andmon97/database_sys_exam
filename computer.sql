create or replace TYPE PACKAGE_TY AS OBJECT
(
    package_ID INTEGER,
    package_name VARCHAR(10),
    package_description VARCHAR(20),
    package_size INTEGER
)FINAL;

CREATE TABLE PACKAGE_TB OF PACKAGE_TY
(
    package_ID PRIMARY KEY,
    package_name NOT NULL,
    package_description NOT NULL,
    package_size NOT NULL
    --CONSTRAINT package_dependency FOREIGN KEY (package_ID) REFERENCES PACKAGE_TB
);

CREATE OR REPLACE TYPE PACK_DEPS_TY AS OBJECT
(
    dep_ID INTEGER,
    package_ID REF PACKAGE_TY,
    package_dep REF PACKAGE_TY
)FINAL;

CREATE TABLE PACK_DEPS_TB OF PACK_DEPS_TY
(
    dep_ID PRIMARY KEY
);

CREATE OR REPLACE TYPE COMPUTER_TY AS OBJECT
(
    computer_ID INTEGER,
    system_description VARCHAR(20)
)FINAL;

CREATE TABLE COMPUTER_TB OF COMPUTER_TY
(
    computer_ID PRIMARY KEY,
    system_description NOT NULL
);


CREATE OR REPLACE TYPE VERSION_TY AS OBJECT
(
    version_ID INTEGER,
    major_rel INTEGER,
    minor_rel INTEGER,
    release_date DATE,
    version_size INTEGER,
    package_dep REF PACKAGE_TY
)FINAL;

CREATE TABLE VERSION_TB OF VERSION_TY
(
    version_ID PRIMARY KEY
);

CREATE OR REPLACE TYPE ADD_DEPENDENCY_TY AS OBJECT
(
    add_dep_ID INTEGER,
    version_dep REF VERSION_TY,
    package_dep REF PACKAGE_TY
)FINAL;

CREATE TABLE ADD_DEPENDENCY_TB OF ADD_DEPENDENCY_TY
(
    add_dep_ID PRIMARY KEY
);

CREATE TYPE INSTALLATION_TY AS OBJECT
(
    installation_ID INTEGER,
    installation_notes VARCHAR(20),
    installation_date DATE,
    installation_version REF VERSION_TY,
    installation_computer REF COMPUTER_TY
)FINAL;

CREATE TABLE INSTALLATION_TB OF INSTALLATION_TY
(
    installation_ID PRIMARY KEY
);





-- Procedures
-- Procudre to populate computer tb
CREATE OR REPLACE PROCEDURE populate_computer_tb AS
iteration number;
BEGIN
iteration := 1;
LOOP
INSERT INTO COMPUTER_TB VALUES (COMPUTER_TY(iteration, DBMS_RANDOM.STRING('U', 20)));
iteration := iteration + 1;
EXIT WHEN iteration > 600;
END LOOP;
END;

-- PACKAGE POP
CREATE OR REPLACE PROCEDURE POPULATE_PACKAGE_TB AS
iteration number;
BEGIN
iteration := 1;
LOOP
INSERT INTO PACKAGE_TB VALUES (PACKAGE_TY(iteration, DBMS_RANDOM.STRING('U', 10), DBMS_RANDOM.STRING('U', 20),
(select trunc(dbms_random.value(0, 50),0) from dual)));
iteration := iteration + 1;
EXIT WHEN iteration > 50;
END LOOP;
END;

-- PACKAGE DEPENDENCIES POP PROCEDURE
CREATE OR REPLACE PROCEDURE POPULATE_PACKAGE_DEPS_TB AS
iteration number;
BEGIN
iteration := 1;
LOOP
-- INSERIMENTO dipendenze scegliendo ref casuali
INSERT INTO PACK_DEPS_TB VALUES (iteration,
(SELECT package_ref FROM ( SELECT REF(P) package_ref FROM PACKAGE_TB P ORDER BY dbms_random.value) WHERE rownum = 1),
(SELECT package_ref FROM ( SELECT REF(P) package_ref FROM PACKAGE_TB P ORDER BY dbms_random.value) WHERE rownum = 1));
iteration := iteration + 1;
EXIT WHEN iteration > 250; 
-- avgh of 5 dep per pack
END LOOP;
END;


-- VERSION TABLE POPULATION
CREATE OR REPLACE PROCEDURE POPULATE_VERSION_TB AS
iteration number;
BEGIN
iteration := 1;
LOOP
-- INSERIMENTO versioni scegliendo ref casuali
INSERT INTO VERSION_TB VALUES (VERSION_TY(iteration,
(select trunc(dbms_random.value(0, 5),0) from dual),
(select trunc(dbms_random.value(0, 10),0) from dual),
(SELECT to_date(trunc(dbms_random.value(to_char(DATE '2000-01-01', 'J'), to_char(DATE '2022-12-31', 'J'))), 'J')FROM DUAL),
(select trunc(dbms_random.value(0, 50),0) from dual),
(SELECT package_ref FROM ( SELECT REF(P) package_ref FROM PACKAGE_TB P ORDER BY dbms_random.value) WHERE rownum = 1)));

iteration := iteration + 1;
EXIT WHEN iteration > 2500; 
-- avgh of 5 major rel and 10 minor per pack
END LOOP;
END;


-- INSTALLATION TABLE POPULATION
CREATE OR REPLACE PROCEDURE POPULATE_INSTALLATION_TB AS
iteration number;
BEGIN
iteration := 1;
LOOP
-- INSERIMENTO versioni e computer scegliendo ref casuali
INSERT INTO INSTALLATION_TB VALUES (INSTALLATION_TY(iteration,
DBMS_RANDOM.STRING('U', 20),
(SELECT to_date(trunc(dbms_random.value(to_char(DATE '2000-01-01', 'J'), to_char(DATE '2022-12-31', 'J'))), 'J')FROM DUAL),
(SELECT version_ref FROM ( SELECT REF(V) version_ref FROM VERSION_TB V ORDER BY dbms_random.value) WHERE rownum = 1),
(SELECT computer_ref FROM ( SELECT REF(C) computer_ref FROM COMPUTER_TB C ORDER BY dbms_random.value) WHERE rownum = 1)
));

iteration := iteration + 1;
EXIT WHEN iteration > 30000; 
-- avgh of 5 major rel and 10 minor per pack
END LOOP;
END;

--addotional PACKAGE DEPENDENCIES for version POP PROCEDURE
CREATE OR REPLACE PROCEDURE POPULATE_ADDITIONAL_DEPS_TB AS
iteration number;
BEGIN
iteration := 1;
LOOP
-- INSERIMENTO dipendenze scegliendo ref casuali
INSERT INTO add_dependency_tb VALUES (ADD_DEPENDENCY_TY(iteration,
(SELECT version_ref FROM ( SELECT REF(V) version_ref FROM VERSION_TB V ORDER BY dbms_random.value) WHERE rownum = 1),
(SELECT package_ref FROM ( SELECT REF(P) package_ref FROM PACKAGE_TB P ORDER BY dbms_random.value) WHERE rownum = 1)));
iteration := iteration + 1;
EXIT WHEN iteration > 150; 
-- avgh of 5 dep per pack
END LOOP;
END;




------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- ACTIVE DB
------------------------------------------------------------------------------------------------------------------------------------

-- A single version of a specific package can be installed on a computer a time
CREATE OR REPLACE TRIGGER CHECK_SAME_PACKAGE
BEFORE INSERT ON INSTALLATION_TB
FOR EACH ROW
DECLARE existPackage NUMBER;

BEGIN
-- controllo se il package risulta gi'a installato
SELECT COUNT(*) INTO existPackage FROM INSTALLATION_TB, VERSION_TB, PACKAGE_TB
WHERE deref(installation_computer).computer_ID = deref(:new.installation_computer).computer_ID
AND deref(installation_version).version_ID = VERSION_TB.version_ID
AND deref(package_dep).package_iD = PACKAGE_TB.package_ID;

IF (existPackage>0) THEN
    raise_application_error(-20012, 'You can install a version a time of the same package on the same computer ');
END IF;
END;    






-- MULTIPLE VERSIONs can have for same package, but different release date
CREATE OR REPLACE TRIGGER CHECK_SAME_PACKVERS_DATE
BEFORE INSERT ON VERSION_TB
FOR EACH ROW
DECLARE existPackage NUMBER;

BEGIN
-- controllo se ci sono gi'a versioni con stessa data dello stesso package
SELECT COUNT(*) INTO existPackage FROM VERSION_TB
WHERE deref(package_dep).package_ID = deref(:new.package_dep).package_ID 
AND release_date = :new.release_date;

IF (existPackage>0) THEN
    raise_application_error(-20012, 'Can t have more version with same release date for the same package ');
END IF;
END;    







---------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--QUERY PROCEDURES
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE CHECK_PACKAGE_INSTALLATION (computerID INTEGER, versionID INTEGER) AS
packageID INTEGER;
alreadyInstalled NUMBER;

BEGIN
alreadyInstalled := 0;

-- retry the package id for the version of interest
SELECT p.package_ID INTO packageID
FROM VERSION_TB v, PACKAGE_TB p
WHERE v.version_ID = versionID
AND DEREF(v.package_dep).package_ID = p.package_ID;


-- check if there are other installation on the given pc for the same version' s package
SELECT COUNT(*) INTO alreadyInstalled
FROM COMPUTER_TB c, INSTALLATION_TB i, VERSION_TB v
WHERE deref(i.installation_version).version_id = v.version_ID
AND deref(v.package_dep).package_ID = packageID
AND deref(i.installation_computer).computer_id = computerID; 

IF (alreadyInstalled > 0) THEN
    raise_application_error(-20013, 'Another version of the same package is already installed in this computer');
ELSE
    dbms_output.put_line('You can proceed with the installation of this version on this computer ...');
END IF;
END;






--op2
create or replace PROCEDURE INSTALL_PACKAGE (packageID INTEGER, computerID INTEGER) AS
packdepid iNTEGER;
countInstallation INTEGER;
packdepname VARCHAR(10);
computerRef ref COMPUTER_TY;
versRef ref VERSION_TY;
packageRef ref PACKAGE_TY;
numDependencies INTEGER;


-- INSTALLARE PRIMA LE DIPENDENZE DEL PACKAGE
CURSOR depCursor IS (
SELECT dep_ID, deref(p.package_Dep).package_ID FROM PACK_DEPS_TB p
WHERE DEREF(p.package_id).package_id = packageID);


dependency depCursor%rowtype;

BEGIN
packdepid :=0;
-- cHECK HOW MANY DEPENDENCIES ARE REQUIRED
SELECT count(*) INTO numDependencies FROM PACK_DEPS_TB p  WHERE  DEREF(p.package_id).package_id = packageID;

IF (numDependencies > 0) Then
OPEN depCursor;
LOOP
FETCH depCursor INTO dependency;
EXIT WHEN depCursor%NOTFOUND;
DBMS_OUTPUT.PUT_LINE('DEPENDENCY REQUIRED: ' || dependency.dep_ID);
END LOOP;
CLOSE depCursor;
RAISE_APPLICATION_ERROR(-20000, 'Install the package after the installation of the required dependencies.');
END IF;

--retrieve last package version
SELECT REF(v) INTO versRef
FROM VERSION_TB v
WHERE  DEREF(v.package_dep).package_ID = packageID
ORDER BY v.release_date DESC
FETCH FIRST 1 ROWS ONLY;

-- COUNT installations
SELECT COUNT(*) into countInstallation FROM INSTALLATION_TB;

--retrieve the computer reference
SELECT REF(t) INTO computerRef FROM COMPUTER_TB t WHERE t.computer_ID = computerID;

-- STORE IN INSTALLATION
INSERT INTO INSTALLATION_TB VALUES(
INSTALLATION_TY( (countInstallation+2), 
DBMS_RANDOM.STRING('U', 20),
(SELECT to_date(trunc(dbms_random.value(to_char(DATE '2000-01-01', 'J'), to_char(DATE '2022-12-31', 'J'))), 'J')FROM DUAL),
versRef, computerRef));

DBMS_OUTPUT.PUT_LINE('Package succesfully installed');
END;






--op3 
create or replace PROCEDURE SEARCH_COMPUTER_PACKAGE(packageID INTEGER) AS
existComputers iNTEGER;

CURSOR computerCursor IS 
    SELECT DISTINCT DEREF(i.installation_computer).computer_id AS computerID, v.release_date as reldate
    FROM INSTALLATION_TB i, VERSION_TB v, COMPUTER_TB c
    WHERE DEREF(i.installation_version).version_ID = v.version_id
    AND DEREF(v.package_dep).package_ID = packageID
    AND DEREF(i.installation_computer).computer_ID = c.computer_ID
    ORDER BY v.release_date;

computers computerCursor%rowtype;


BEGIN
    existComputers := 0;
    SELECT COUNT(*) INTO existComputers
    FROM INSTALLATION_TB i, VERSION_TB v, COMPUTER_TB c
    WHERE DEREF(v.package_dep).package_ID = 1
    AND DEREF(i.installation_computer).computer_ID = c.computer_ID;

    IF (existComputers>0) THEN
        OPEN computerCursor;
        LOOP
        FETCH computerCursor INTO computers;
        EXIT WHEN computerCursor%NOTFOUND;
        DBMS_OUTPUT.PUT_LINE('COMPUTER ID: ' || computers.computerID || ' VERSION RELEASE DATE ' || computers.reldate);
        END LOOP;
        CLOSE computerCursor;
    ELSE
        RAISE_APPLICATION_ERROR(-20000, 'There are no computer with this package installed on.');
    END IF;
END;





-- OP4 print all the packages and numb of comps on which the package is installed
create or replace PROCEDURE SHOW_PACK_INSTALLED_COMPUTER AS
existpackage INTEGER;

CURSOR queryCursor IS (

SELECT DISTINCT p.package_ID as packageID, COUNT (*) AS countComp
FROM PACKAGE_TB p, VERSION_TB v, INSTALLATION_TB i, COMPUTER_TB c
WHERE DEREF(v.package_dep).package_ID = p.package_ID
AND DEREF(i.installation_version).version_ID = v.version_ID
AND DEREF(i.installation_computer).computer_ID = c.computer_ID
GROUP BY p.package_ID
);
requery queryCursor%rowtype;


BEGIN

    OPEN queryCursor;
    LOOP
    FETCH queryCursor INTO requery;
    EXIT WHEN queryCursor%notfound;
    DBMS_OUTPUT.PUT_LINE('LIST OF PACKAGE');
    DBMS_OUTPUT.PUT_LINE('ID PACKAGE: ' || requery.packageID || ' PC ON WHICH IS INSTALLED: ' || requery.CountComp);
    DBMS_OUTPUT.PUT_LINE(' ');
    END LOOP;
    CLOSE queryCursor;
END;



--OP5 delete of a computer
create or replace PROCEDURE REMOVE_COMPUTER(computerID INTEGER) AS
existComputer INTEGER;

BEGIN
    existcomputer := 0;
    SELECT COUNT(*) into existcomputer
    FROM COMPUTER_TB WHERE computer_id = computerID;

    IF (existcomputer>0) THEN
        DELETE FROM INSTALLATION_TB
        WHERE DEREF(installation_computer).computer_ID = computerID;

        DELETE FROM computer_tb
        WHERE computer_id=computer_ID;

        DBMS_OUTPUT.PUT('Computer DELETEDfrom the database  with all its installations');

    ELSE
        RAISE_APPLICATION_ERROR(-20000, 'The computer does not exist, can t remove it.'); 
    END IF;
END;




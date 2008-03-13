-- $Id: apq-sybase-client.ads,v 1.25 2004/10/04 03:48:06 wwg Exp $
-- Copyright (c) 2003, Warren W. Gay VE3WWG
--
-- Licensed under the ACL (Ada Community License)
-- or
-- GNU Public License 2 (GPL2)
-- 
--     This program is free software; you can redistribute it and/or modify
--     it under the terms of the GNU General Public License as published by
--     the Free Software Foundation; either version 2 of the License, or
--     (at your option) any later version.
-- 
--     This program is distributed in the hope that it will be useful,
--     but WITHOUT ANY WARRANTY; without even the implied warranty of
--     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
--     GNU General Public License for more details.
-- 
--     You should have received a copy of the GNU General Public License
--     along with this program; if not, write to the Free Software
--     Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

with System;
with Interfaces;
with Ada.Text_IO.C_Streams;
with Ada.Finalization;
with Ada.Streams.Stream_IO;
with Ada.Calendar;
with Ada.Strings.Bounded;
with Ada.Strings.Unbounded;
with Interfaces.C_Streams;

package APQ.Sybase.Client is

   package Str renames Ada.Streams;
   package CStr renames Interfaces.C_Streams;

   ------------------------------
   -- CLIENT DATA TYPES
   ------------------------------
   type Connection_Type is new APQ.Root_Connection_Type with private;
   type Connection_Ptr is access all Connection_Type;

   type Query_Type is new APQ.Root_Query_Type with private;

   ------------------------------
   -- DATABASE CONNECTION :
   ------------------------------

   function Engine_Of(C : Connection_Type) return Database_Type;
   function New_Query(C : Connection_Type) return Root_Query_Type'Class;

   -- This actually sets the "Application Name", which may in turn influence the database chosen
   procedure Set_DB_Name(C : in out Connection_Type; DB_Name : String);

   procedure Set_Options(C : in out Connection_Type; Options : String);
   function Options(C : Connection_Type) return String;

   procedure Connect(C : in out Connection_Type);
   procedure Connect(C : in out Connection_Type; Same_As : Root_Connection_Type'Class);
   procedure Disconnect(C : in out Connection_Type);

   function Is_Connected(C : Connection_Type) return Boolean;
   procedure Reset(C : in out Connection_Type);
   function Error_Message(C : Connection_Type) return String;

   -- Open trace output file
   procedure Open_DB_Trace(C : in out Connection_Type; Filename : String; Mode : Trace_Mode_Type := Trace_APQ);
   procedure Close_DB_Trace(C : in out Connection_Type);                         -- Close trace output file
   procedure Set_Trace(C : in out Connection_Type; Trace_On : Boolean := True);  -- Enable/Disable tracing
   function Is_Trace(C : Connection_Type) return Boolean;                        -- Test trace enabled/disabled

   function In_Abort_State(C : Connection_Type) return Boolean;

   ------------------------------
   -- SQL QUERY API :
   ------------------------------

   procedure Clear(Q : in out Query_Type);
   procedure Append(Q : in out Query_Type; V : APQ_Boolean; After : String := "");
   procedure Append_Quoted(Q : in out Query_Type; Connection : Root_Connection_Type'Class; SQL : String; After : String := "");
   procedure Set_Fetch_Mode(Q : in out Query_Type; Mode : Fetch_Mode_Type);

   procedure Execute(Query : in out Query_Type; Connection : in out Root_Connection_Type'Class);
   procedure Execute_Checked(Query : in out Query_Type; Connection : in out Root_Connection_Type'Class; Msg : String := "");

   procedure Begin_Work(Query : in out Query_Type; Connection : in out Root_Connection_Type'Class);
   procedure Commit_Work(Query : in out Query_Type; Connection : in out Root_Connection_Type'Class);
   procedure Rollback_Work(Query : in out Query_Type; Connection : in out Root_Connection_Type'Class);

   procedure Rewind(Q : in out Query_Type); -- Not supported
   procedure Fetch(Q : in out Query_Type);

   procedure Fetch(Q : in out Query_Type; TX : Tuple_Index_Type); -- Not supported
   function End_of_Query(Q : Query_Type) return Boolean;          -- Not supported

   function Tuple(Q : Query_Type) return Tuple_Index_Type;
   function Tuples(Q : Query_Type) return Tuple_Count_Type;

   function Columns(Q : Query_Type) return Natural;
   function Column_Name(Q : Query_Type; CX : Column_Index_Type) return String;
   function Column_Index(Q : Query_Type; Name : String) return Column_Index_Type;
   function Column_Type(Q : Query_Type; CX : Column_Index_Type) return Field_Type;

   function Is_Null(Q : Query_Type; CX : Column_Index_Type) return Boolean;
   function Value(Query : Query_Type; CX : Column_Index_Type) return String;

   function Result(Query : Query_Type) return Natural;            -- Returns Result_Type'Pos()  (for generics)
   function Result(Query : Query_Type) return Result_Type;
   function Command_Oid(Query : Query_Type) return Row_ID_Type;   -- Raises Not_Supported
   function Null_Oid(Query : Query_Type) return Row_ID_Type;      -- Raises Not_Supported

   function Error_Message(Query : Query_Type) return String;
   function Is_Duplicate_Key(Query : Query_Type) return Boolean;
   function Engine_Of(Q : Query_Type) return Database_Type;

   function Cursor_Name(Query : Query_Type) return String;
   function SQL_Code(Query : Query_Type) return SQL_Code_Type;

private

   type Connection_Type is new APQ.Root_Connection_Type with
      record
         Options :         String_Ptr;                         -- Sybase database engine options
         Context :         Sy_Context_Type := Null_Context;    -- Sybase context
         Connection :      Sy_Conn_Type := Null_Connection;    -- Sybase connection object
         Connected :       Boolean := False;                   -- True when connected
         SQLCA :           SQLCA_Ptr;                          -- SQL Communications Area
         Sy_Database :     String_Ptr;                         -- Deferred database change
      end record;

   procedure Finalize(C : in out Connection_Type);
   procedure Initialize(C : in out Connection_Type);

   function query_factory(C: in Connection_Type) return Root_Query_Type'Class;

   type Cursor_Name_Type is new String(1..10);              -- Sybase cursor name

   type Query_Type is new APQ.Root_Query_Type with
      record
         Cursor_Name :     Cursor_Name_Type;                -- Generated cursor name
         SQLCA :           SQLCA_Ptr;                       -- As last used by Connection_Type (cheat)
         Cmd :             Sy_Cmd_Type := Null_Command;     -- Sybase command that was executed
         Results :         Result_Type := No_Results;       -- Query execution results
         Columns :         Natural := 0;                    -- # of columns in row data
         Values :          Sy_Columns_Ptr;                  -- Described columns and their values
         Row_ID :          Row_ID_Type;                     -- Extracted from @@identity
      end record;

   procedure Initialize(Q : in out Query_Type);
   procedure Adjust(Q : in out Query_Type);
   procedure Finalize(Q : in out Query_Type);

   -- Callback registration

   type Client_Msg_CB is access
      procedure(
         Connection :         System.Address;
         Message_Layer :      APQ.Sybase.Layer_Type;
         Message_Origin :     APQ.Sybase.Origin_Type;
         Message_Severity :   APQ.Sybase.Severity_Type;
         Message_Number :     APQ.Sybase.Message_Number_Type;
         Message :            Interfaces.C.strings.chars_ptr;
         Message_Length :     APQ.Sybase.Int_Type;
         OS_Message :         Interfaces.C.strings.chars_ptr;
         OS_Message_Length :  APQ.Sybase.Int_Type
     );

   pragma Export(C,Client_Msg_CB,"client_msg_cb");

   type Server_Msg_CB is access
      procedure(
         Connection :         System.Address;
         Message_Severity :   APQ.Sybase.Severity_Type;
         Message_Number :     APQ.Sybase.Message_Number_Type;
         State :              APQ.Sybase.State_Type;
         Line :               APQ.Sybase.Line_Type;
         Server_Name :        Interfaces.C.Strings.chars_ptr;
         Server_Name_Length : APQ.Sybase.Int_Type;
         Proc_Name :          Interfaces.C.Strings.chars_ptr;
         Proc_Name_Length :   APQ.Sybase.Int_Type;
         Message :            Interfaces.C.Strings.chars_ptr
      );
   pragma Export(C,Server_Msg_CB,"server_msg_cb");

   procedure Set_Client_CB(Proc : Client_Msg_CB);
   procedure Set_Server_CB(Proc : Server_Msg_CB);

   procedure Sy_Client_CB(
      Connection :         System.Address;
      Message_Layer :      APQ.Sybase.Layer_Type;
      Message_Origin :     APQ.Sybase.Origin_Type;
      Message_Severity :   APQ.Sybase.Severity_Type;
      Message_Number :     APQ.Sybase.Message_Number_Type;
      Message :            Interfaces.C.Strings.chars_ptr;
      Message_Length :     APQ.Sybase.Int_Type;
      OS_Message :         Interfaces.C.Strings.chars_ptr;
      OS_Message_Length :  APQ.Sybase.Int_Type
   );
   pragma Export(C,Sy_Client_CB,"sy_client_cb");

   procedure Sy_Server_CB(
      Connection :         System.Address;
      Message_Severity :   APQ.Sybase.Severity_Type;
      Message_Number :     APQ.Sybase.Message_Number_Type;
      State :              APQ.Sybase.State_Type;
      Line :               APQ.Sybase.Line_Type;
      Server_Name :        Interfaces.C.Strings.chars_ptr;
      Server_Name_Length : APQ.Sybase.Int_Type;
      Proc_Name :          Interfaces.C.Strings.chars_ptr;
      Proc_Name_Length :   APQ.Sybase.Int_Type;
      Message :            Interfaces.C.Strings.chars_ptr
   );
   pragma Export(C,Sy_Server_CB,"sy_server_cb");
 

end APQ.Sybase.Client;

-- End $Source: /cvsroot/apq/apq/apq-sybase-client.ads,v $

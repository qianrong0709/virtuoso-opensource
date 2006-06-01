--
--  $Id$
--
--  Procedures to support the WA search.
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2006 OpenLink Software
--
--  This project is free software; you can redistribute it and/or modify it
--  under the terms of the GNU General Public License as published by the
--  Free Software Foundation; only version 2 of the License, dated June 1991.
--
--  This program is distributed in the hope that it will be useful, but
--  WITHOUT ANY WARRANTY; without even the implied warranty of
--  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
--  General Public License for more details.
--
--  You should have received a copy of the GNU General Public License along
--  with this program; if not, write to the Free Software Foundation, Inc.,
--  51 Franklin St, Fifth Floor, Boston, MA 02110-1301 USA
--
--

create function WA_SEARCH_ADD_SID_IF_AVAILABLE (in url varchar, in _user_id integer, in connector varchar := '?')
returns varchar
{
  declare _sid varchar;
  declare ret varchar;
  _sid := connection_get ('wa_sid');
  if (_user_id <> http_nobody_uid() and isstring (_sid) and _sid <> '')
    ret := url || connector || 'sid=' || _sid || '&realm=wa';
  else
    ret := url;
  --dbg_obj_print ('WA_SEARCH_ADD_SID_IF_AVAILABLE', 'url=', url, '_user_id=', _user_id, 'connector=', connector, '_sid=', _sid, 'ret=', ret);
  return ret;
}
;

create function WA_SEARCH_ADD_APATH (in url varchar)
returns varchar
{
  return WS.WS.EXPAND_URL (connection_get ('WA_SEARCH_PATH'), url);
}
;

-- function to return the virt:// path for a WA resource : this is an optimization
-- for XSLT so as to not do http_client back to itself for a stylesheet.
-- params : path relative to the wa dir
-- output : the virt:// url for the incoming path
create function WA_GET_PPATH_URL (in f varchar)
returns varchar
{
  declare rc any;
  if (http_map_get ('is_dav'))
    {
      rc :=  concat (
      'virt://WS.WS.SYS_DAV_RES.RES_FULL_PATH.RES_CONTENT:',
      registry_get('_wa_path_'), f);
    }
  else
    {
      rc := concat ('file:/', registry_get('_wa_path_'), f);
    }

  return rc;
}
;

create procedure WA_SEARCH_USER_GET_APPS_LIST (
	in _user_id integer,
	in _U_NAME varchar,
        in _U_E_MAIL varchar,
        in for_search_result integer,
        in _WAUT_USER_ID integer
)
returns varchar
{
  declare res varchar;
  res := '';

  for select INST_TYPE, count (*) as INST_COUNT, MAX (INST_NAME) as _INST_NAME
     from WA_USER_APP_INSTANCES where user_id = _user_id and fname = _U_NAME
     group by INST_TYPE do
    {
      if (res <> '')
        res := res || ' ';

      declare icon varchar;

      icon := sprintf (case INST_TYPE
        when 'WEBLOG2' then 'images/icons/blog_%d.png'
        when 'oWiki' then 'images/icons/wiki_%d.png'
        when 'eNews2' then 'images/icons/enews_%d.png'
        when 'oMail' then 'images/icons/mail_%d.png'
        when 'oDrive' then 'images/icons/odrive_%d.png'
        when 'oGallery' then 'images/icons/ogallery_%d.png'
        else 'images/icons/apps_%d.png'
      end,
      case when for_search_result then 16 else 24 end);

      declare url, amp varchar;

      if (INST_COUNT > 1)
        {
	  url := sprintf ('app_inst.vspx?app=%U&ufname=%U', INST_TYPE, _U_NAME);
	  amp := '&';
        }
      else
        {
          url := (select x.WAI_INST.wa_home_url () from WA_INSTANCE x where x.WAI_NAME = _INST_NAME);
          amp := '?';
        }
      if (url like 'javascript:%')
	url := '#';
      res := res || sprintf (
          '<a href="%s"><img src="%s" alt="%s" border="0" title="%s" /></a>',
          WA_SEARCH_ADD_APATH (
            WA_SEARCH_ADD_SID_IF_AVAILABLE (
	      url, _user_id, amp)),
          WA_SEARCH_ADD_APATH (icon),
          INST_TYPE, WA_GET_APP_NAME (INST_TYPE));
    }

  if (res <> '')
    res := res || ' ';
  if (_user_id <> http_nobody_uid () and _user_id <> _WAUT_USER_ID
       --and _WAUT_USER_ID <> http_dav_uid () and _WAUT_USER_ID <> 0
       and (not WA_USER_IS_FRIEND (_user_id, _WAUT_USER_ID)))
    {
      res := res || sprintf ('<a href="%s"><img src="%s" alt="Add to Friends" border="0" title="Add to Friends" /></a>',
	  WA_SEARCH_ADD_APATH (
	    WA_SEARCH_ADD_SID_IF_AVAILABLE (
	      sprintf ('sn_make_inv.vspx?fmail=%U', _U_E_MAIL),
	      _user_id, '&')),
	      WA_SEARCH_ADD_APATH (sprintf ('images/icons/add_user_%d.png', case when for_search_result then 16 else 24 end)));
    }
  return res;
}
;


create function WA_SEARCH_USER_GET_EXCERPT_HTML (
	in _user_id integer,
	in words any,
	in _WAUT_USER_ID integer,
	in txt varchar,
	in _WAUI_FULL_NAME varchar,
	in _U_NAME varchar,
	in _WAUI_PHOTO_URL long varchar,
        in _U_E_MAIL varchar,
        in for_search_result integer := 0
) returns varchar
{
  declare res varchar;
  declare icons varchar;
--  dbg_obj_print ('for_search_result=', for_search_result);

  icons := WA_SEARCH_USER_GET_APPS_LIST (_user_id, _U_NAME, _U_E_MAIL, for_search_result, _WAUT_USER_ID);
--  dbg_obj_print ('icons=', icons);

  _WAUI_PHOTO_URL := blob_to_string (_WAUI_PHOTO_URL);

  if (not length (_WAUI_FULL_NAME))
    _WAUI_FULL_NAME := _U_NAME;

  if (for_search_result)
    {
      res := sprintf (
	 '<span><img class="%s" src="%s" alt="user_photo" border="0"/> <a href="%s">%s</a>%s<br />%s</span>',
         case when _WAUI_PHOTO_URL is not null then 'user_photo_report'  else 'user_icon_report' end,
	 WA_SEARCH_ADD_APATH (coalesce (_WAUI_PHOTO_URL, 'images/icons/user_16.png')),
	 WA_SEARCH_ADD_APATH (
	    WA_SEARCH_ADD_SID_IF_AVAILABLE (sprintf ('uhome.vspx?ufname=%U', _U_NAME), _user_id, '&')),
	 _WAUI_FULL_NAME,
         icons,
	 left (search_excerpt (words, subseq (coalesce (txt, ''), 0, 200000)), 900));
    }
  else
    {
      res := sprintf (
	 '<div class="map_user_data"><a href="%s">%s''s Data Spaces</a><br />%s<br /><img class="%s" src="%s" alt="user_photo" border="0"/><br />%s</div>',
	 WA_SEARCH_ADD_APATH (
	    WA_SEARCH_ADD_SID_IF_AVAILABLE (sprintf ('uhome.vspx?ufname=%U', _U_NAME), _user_id, '&')),
	 _WAUI_FULL_NAME,
         icons,
         case when _WAUI_PHOTO_URL is not null then 'user_photo_map' else 'icon_icon_map' end,
	 WA_SEARCH_ADD_APATH (coalesce (_WAUI_PHOTO_URL, 'images/icons/user_16.png')),
	 left (search_excerpt (words, subseq (coalesce (txt, ''), 0, 200000)), 900));
    }

  return res;
}
;

create function WA_SEARCH_USER_GET_EXCERPT_HTML_CUSTOMODSPATH (
	in _user_id integer,
	in words any,
	in _WAUT_USER_ID integer,
	in txt varchar,
	in _WAUI_FULL_NAME varchar,
	in _U_NAME varchar,
	in _WAUI_PHOTO_URL long varchar,
  in _U_E_MAIL varchar,
  in for_search_result integer := 0,
  in _wa_home varchar := null
) returns varchar
{


  declare res varchar;
  declare icons varchar;
--  dbg_obj_print ('for_search_result=', for_search_result);

  if (_wa_home is null)
    _wa_home := wa_link ();

  connection_set ('WA_SEARCH_PATH',_wa_home);


  icons := WA_SEARCH_USER_GET_APPS_LIST (_user_id, _U_NAME, _U_E_MAIL, for_search_result, _WAUT_USER_ID);

  _WAUI_PHOTO_URL := blob_to_string (_WAUI_PHOTO_URL);

  if (not length (_WAUI_FULL_NAME))
    _WAUI_FULL_NAME := _U_NAME;

  if (for_search_result)
    {
      res := sprintf (
	 '<span><img class="%s" src="%s" alt="user_photo" border="0"/> <a href="%s">%s</a>%s<br />%s</span>',
         case when _WAUI_PHOTO_URL is not null then 'user_photo_report'  else 'user_icon_report' end,
	 WA_SEARCH_ADD_APATH (coalesce (_WAUI_PHOTO_URL, 'images/icons/user_16.png')),
	 WA_SEARCH_ADD_APATH (
	    WA_SEARCH_ADD_SID_IF_AVAILABLE (sprintf ('uhome.vspx?ufname=%U', _U_NAME), _user_id, '&')),
	 _WAUI_FULL_NAME,
         icons,
	 left (search_excerpt (words, subseq (coalesce (txt, ''), 0, 200000)), 900));
    }
  else
    {
      res := sprintf (
	 '<div class="map_user_data"><a href="%s">%s''s Data Space</a><br />%s<br /><img class="%s" src="%s" alt="user_photo" border="0"/><br />%s</div>',
	 WA_SEARCH_ADD_APATH (
	    WA_SEARCH_ADD_SID_IF_AVAILABLE (sprintf ('uhome.vspx?ufname=%U', _U_NAME), _user_id, '&')),
	 _WAUI_FULL_NAME,
         icons,
         case when _WAUI_PHOTO_URL is not null then 'user_photo_map' else 'icon_icon_map' end,
	 WA_SEARCH_ADD_APATH (coalesce (_WAUI_PHOTO_URL, 'images/icons/user_16.png')),
	 left (search_excerpt (words, subseq (coalesce (txt, ''), 0, 200000)), 900));
    }

  return res;
}
;

create function WA_SEARCH_WORDS_TO_VECTOR_CALL (in _words any) returns varchar
{
  declare _ses varchar;
  _ses := '';

  foreach (varchar _word in _words) do
    {
      if (_ses <> '')
        _ses := _ses || ',';
      _ses := _ses || sprintf ('''%V''', _word);
    }
  return 'vector (' || _ses || ')';
}
;


create procedure WA_SEARCH_PROCESS_PARAMS (in nqry nvarchar, in ntags_list nvarchar, in tag_is_qry int,
  out str varchar, out tags_str varchar, out _words_vector varchar, out tags_vector any)
{
  declare qry, tags_list any;
  declare _words any;

  qry := trim (charset_recode (nqry, '_WIDE_', 'UTF-8'));
  tags_list := trim (charset_recode (ntags_list, '_WIDE_', 'UTF-8'));

  --dbg_obj_print ('qry=', qry, ' len=', length (qry));
  if (length (qry) >= 2)
    {
      str := FTI_MAKE_SEARCH_STRING_INNER (qry, _words);

      if (length (_words) > 9)
	 signal ('22023',
	   sprintf ('Too many (%d) search words in phrase %s. Only 9 allowed',
	     length (_words), qry),
	   'WAS02');

      _words_vector := WA_SEARCH_WORDS_TO_VECTOR_CALL (_words);
    }
  else
    {
      str := NULL;
      _words_vector := 'vector ()';
      _words := vector ();
    }

  --dbg_obj_print ('tags_list=', tags_list, ' len=', length (tags_list));
  if (length (tags_list) >= 2)
    {
      declare new_tv any;
      if (tag_is_qry = 0)
	{
      tags_str := WS.WS.DAV_TAG_NORMALIZE (tags_list);
      tags_str := FTI_MAKE_SEARCH_STRING (tags_str);
        }
      else
	tags_str := tags_list;
      tags_vector := split_and_decode (tags_str, 0, '\0\0 ');
      new_tv := vector ();
      foreach (varchar _tag in tags_vector) do
        {
          if (isstring (_tag))
            {
               new_tv := vector_concat (new_tv, vector (replace (_tag, '"', '')));
            }
        }
      tags_vector := new_tv;
    }
  else
    {
      tags_vector := NULL;
      tags_str := NULL;
    }

  if ((length (tags_list) or length (qry)) and tags_str is null and str is null)
    signal ('22023', 'No expression entered', 'WAS01');
  --dbg_obj_print ('str=', str, ' tags_str=', tags_str);
}
;

-- TODO: check the visibility (permissions) of the users !!!
create function WA_SEARCH_USER_BASE (in max_rows integer, in current_user_id integer,
   in str varchar, in tags_str varchar, in _words_vector varchar) returns varchar
{
  declare ret varchar;

  if (str is null and tags_str is null)
    {
      ret := sprintf (
	'select \n' ||
	'  WAUT_U_ID, WAUT_TEXT, (0 + 0) as _SCORE \n' ||
	' from \n' ||
        '  WA_USER_TEXT \n');
    }
  else if (str is null)
    {
      ret := sprintf (
	'select \n' ||
	'  WAUT_U_ID, WAUT_TEXT, SCORE as _SCORE \n' ||
	' from \n' ||
        '  WA_USER_TAG, WA_USER_TEXT table option (loop)\n' ||
        ' where \n' ||
        '  contains (WAUTG_TAGS, ''[__lang "x-ViDoc" __enc "UTF-8"] (%S) AND ("^UID%d" or "^PUBLIC")'', \n' ||
        '    OFFBAND,WAUTG_TAG_ID,OFFBAND,WAUTG_U_ID) \n' ||
        '  and WAUTG_TAG_ID = WAUT_U_ID \n'
         , tags_str,
          current_user_id);
    }
  else
    {
      ret := sprintf(
	'SELECT WAUT_U_ID, WAUT_TEXT, SCORE as _SCORE FROM WA_USER_TEXT WAUT \n' ||
	' WHERE \n' ||
	'   contains (WAUT_TEXT, ''[__lang "x-any" __enc "UTF-8"] (%S)'') \n',
	str);

      if (tags_str is not null)
	ret := sprintf (
	  '%s and exists ( \n' ||
	  '  SELECT 1 FROM WA_USER_TAG \n' ||
	  '    WHERE \n' ||
	  '      contains (WAUTG_TAGS, \n' ||
	  '        sprintf (\n' ||
          '         ''[__lang "x-ViDoc" __enc "UTF-8"] (%S) AND "^TID%%d" AND ("^UID%d" or "^PUBLIC")'', \n' ||
          '         WAUT.WAUT_U_ID), \n' ||
	  '        OFFBAND,WAUTG_TAG_ID,OFFBAND,WAUTG_U_ID)) \n',
	  ret,
	  tags_str,
          current_user_id);
     }
  return ret;
}
;


create function WA_SEARCH_USER (in max_rows integer, in current_user_id integer,
   in str varchar, in tags_str varchar, in _words_vector varchar) returns varchar
{
  declare ret varchar;

  ret := WA_SEARCH_USER_BASE (max_rows, current_user_id, str, tags_str, _words_vector);

  ret := sprintf (
	 'select top %d * from (\n' ||
	 ' select top %d \n' ||
	 '  WA_SEARCH_USER_GET_EXCERPT_HTML (%d, %s, WAUT_U_ID, WAUT_TEXT, WAUI_FULL_NAME, U_NAME, WAUI_PHOTO_URL, U_E_MAIL, 1) AS EXCERPT, \n' ||
	 '  encode_base64 (serialize (vector (''USER'', WAUT_U_ID))) as TAG_TABLE_FK, \n' ||
	 '  _SCORE, \n' ||
	 '  U_LOGIN_TIME _DATE \n' ||
	 ' from \n(\n%s\n) qry, DB.DBA.WA_USER_INFO, DB.DBA.SYS_USERS, DB.DBA.sn_person \n' ||
         ' where \n' ||
         '  WAUT_U_ID = WAUI_U_ID and WAUI_SEARCHABLE = 1\n' ||
         '  and U_NAME = sne_name\n' ||
         '  and WAUT_U_ID = U_ID\n' ||
         'option (order)) oq',
    max_rows, max_rows, current_user_id, _words_vector, ret);

  return ret;
}
;

-- creates a search excerpt for a blog.
-- see http://wiki.usnet.private:8791/twiki/bin/view/Main/VirtWASpecsRevisions#Advanced_Search for description
-- params : words : an array of search words (as returned by the FTI_MAKE_SEARCH_STRING_INNER
-- returns the XHTML fragment
--exec ('
wa_exec_no_error('
create function WA_SEARCH_BLOG_GET_EXCERPT_HTML (in _current_user_id integer,
	in _B_BLOG_ID varchar, in _B_POST_ID varchar,
	in words any, in _B_CONTENT varchar, in _B_TITLE varchar) returns varchar
{
  declare _BI_PHOTO, _BI_TITLE, _BI_HOME, _BI_HOME_PAGE varchar;
  declare _BI_OWNER integer;
  declare _WAUI_FULL_NAME varchar;
  declare _single_post_view_url, _blog_front_page_url varchar;
  declare res varchar;

  select BI_PHOTO, BI_TITLE, BI_HOME, BI_OWNER, BI_HOME_PAGE
     into _BI_PHOTO, _BI_TITLE, _BI_HOME, _BI_OWNER, _BI_HOME_PAGE
     from BLOG..SYS_BLOG_INFO where BI_BLOG_ID = _B_BLOG_ID;

  _single_post_view_url := WA_SEARCH_ADD_APATH (WA_SEARCH_ADD_SID_IF_AVAILABLE (
	sprintf (\'%s?id=%s\', _BI_HOME, _B_POST_ID),
	_current_user_id,
        \'&\'));
  _blog_front_page_url := WA_SEARCH_ADD_APATH (WA_SEARCH_ADD_SID_IF_AVAILABLE (_BI_HOME, _current_user_id));

  select WAUI_FULL_NAME
     into _WAUI_FULL_NAME
     from DB.DBA.WA_USER_INFO where WAUI_U_ID = _BI_OWNER;

  res := sprintf (\'<span><img src="%s" /> <a href="%s">%s</a> <a href="%s">%s</a> by \',
           WA_SEARCH_ADD_APATH (''images/icons/blog_16.png''),
	   _single_post_view_url, _B_TITLE,
	   _blog_front_page_url, _BI_TITLE);

  if (_BI_HOME_PAGE is not null and _BI_HOME_PAGE <> \'\')
    res := res || sprintf (\'<a href="%s">\', _BI_HOME_PAGE);
  else
    res := res || \'<b>\';

  res := res || _WAUI_FULL_NAME;

  if (_BI_HOME_PAGE is not null and _BI_HOME_PAGE <> \'\')
    res := res || \'</a>\';
  else
    res := res || \'</b>\';

  res := res || \'<br />\' ||
    left (
      search_excerpt (
        words,
        subseq (coalesce (_B_CONTENT, \'\'), 0, 200000)
      ),
      900) || \'</span>\';

  return res;
}')
;


-- makes a SQL query for WA search over the BLOG posts
create function WA_SEARCH_BLOG (in max_rows integer, in current_user_id integer,
   in str varchar, in tags_str varchar, in _words_vector varchar) returns any
{
  declare ret varchar;

  if (str is null and tags_str is null)
    {
      ret :=
	'SELECT B_BLOG_ID, B_CONTENT, B_POST_ID, B_TITLE, 0 as _SCORE, B_MODIFIED as _DATE \n' ||
        ' FROM \n' ||
        '  BLOG.DBA.SYS_BLOGS\n';
    }
  else if (str is null)
    {
      ret := sprintf (
	'SELECT B_BLOG_ID, B_CONTENT, B_POST_ID, B_TITLE, SCORE as _SCORE, B_MODIFIED as _DATE \n' ||
        ' FROM \n' ||
        '  BLOG.DBA.SYS_BLOGS,\n' ||
        '  BLOG.DBA.BLOG_TAG\n' ||
	' WHERE \n' ||
	'   contains (BT_TAGS, ''[__lang "x-ViDoc" __enc "UTF-8"] (%S)'') \n' ||
	'   and B_POST_ID = BT_POST_ID \n',
        tags_str);
    }
  else
    {
      ret := sprintf(
	'SELECT B_BLOG_ID, B_CONTENT, B_POST_ID, B_TITLE, SCORE as _SCORE, B_MODIFIED as _DATE FROM BLOG.DBA.SYS_BLOGS SYBL \n' ||
	' WHERE \n' ||
	'   contains (B_CONTENT, ''[__lang "x-any" __enc "UTF-8"] %S'',descending) \n',
	str);

      if (tags_str is not null)
	ret := sprintf (
	  '%s and exists ( \n' ||
	  '  SELECT 1 FROM BLOG.DBA.BLOG_TAG \n' ||
	  '    WHERE \n' ||
	  '      contains (BT_TAGS, \n' ||
	  '        sprintf (''[__lang "x-ViDoc" __enc "UTF-8"] (%S) AND (B%%S)'', ' ||
	  '          replace (SYBL.B_BLOG_ID, ''-'', ''_'')), OFFBAND,BT_BLOG_ID,OFFBAND,BT_POST_ID)  ' ||
          '      and B_POST_ID = BT_POST_ID) \n',
	  ret,
	  tags_str);
    }

  ret := sprintf (
         'select top %d \n' ||
         '  WA_SEARCH_BLOG_GET_EXCERPT_HTML (%d, B_BLOG_ID, B_POST_ID, %s, B_CONTENT, B_TITLE) AS EXCERPT, \n' ||
         '  encode_base64 (serialize (vector (''BLOG'', vector (B_BLOG_ID, B_POST_ID)))) as TAG_TABLE_FK, \n' ||
         '  _SCORE, \n' ||
         '  _DATE \n' ||
         ' from \n(\n%s\n) qry',
    max_rows, current_user_id, _words_vector, ret);

  return ret;
}
;


-- creates a search excerpt for a DAV resource.
-- see http://wiki.usnet.private:8791/twiki/bin/view/Main/VirtWASpecsRevisions#Advanced_Search for description
-- params :
--     words : an array of search words (as returned by the FTI_MAKE_SEARCH_STRING_INNER
-- returns the XHTML fragment
create function WA_SEARCH_DAV_GET_EXCERPT_HTML (in _current_user_id integer, in _RES_ID integer,
	in words any, in _RES_CONTENT varchar, in _RES_FULL_PATH varchar) returns varchar
{
  declare _COL_PATH varchar;
  declare _COL_PATH_ARRAY varchar;
  declare res varchar;
  declare _sid varchar;
  declare _content any;

  _COL_PATH := DB.DBA.DAV_CONCAT_PATH (WS.WS.PARENT_PATH (WS.WS.HREF_TO_PATH_ARRAY (_RES_FULL_PATH)), null);

  res := sprintf ('<span><a href="%s"><img src="%s" /></a><a href="%s">%s</a>',
	   WA_SEARCH_ADD_APATH (_COL_PATH),
           WA_SEARCH_ADD_APATH ('images/icons/dav_16.png'),
	   WA_SEARCH_ADD_APATH (_RES_FULL_PATH), _RES_FULL_PATH);

  _content := coalesce (_RES_CONTENT, '');
  if (not isblob (_content))
    _content := cast (_content as varchar);
  _content := subseq (_content, 0, 200000);
  res := res || '<br />' || left (search_excerpt (words, _content), 900) || '</span>';

  return res;
}
;

--exec ('
wa_exec_no_error('
create function WA_SEARCH_WIKI_GET_EXCERPT_HTML (in _current_user_id integer, in _RES_ID integer,
	in words any, in _RES_CONTENT varchar, in _RES_FULL_PATH varchar, in _RES_OWNER integer) returns varchar
{
  declare _COL_PATH, _WIKI_PATH, _WIKI_INSTANCE_PATH varchar;
  declare _COL_PATH_ARRAY varchar;
  declare _TitleText nvarchar;
  declare _ClusterName, _LocalName varchar;
  declare res varchar;
  declare _WAUI_FULL_NAME varchar;
  declare _U_NAME varchar;
  declare _content any;

  _COL_PATH := DB.DBA.DAV_CONCAT_PATH (WS.WS.PARENT_PATH (WS.WS.HREF_TO_PATH_ARRAY (_RES_FULL_PATH)), null);

  _TitleText := null; _ClusterName := null; _LocalName := null;
  select coalesce (TitleText, cast (LocalName as nvarchar)), ClusterName, LocalName
    into _TitleText, _ClusterName, _LocalName
    from WV.WIKI.TOPIC T, WV.WIKI.CLUSTERS C
    where
      T.ClusterId = C.ClusterId
      and ResId = _RES_ID;

  _WAUI_FULL_NAME := null;
  select WAUI_FULL_NAME
    into _WAUI_FULL_NAME
    from DB.DBA.WA_USER_INFO where WAUI_U_ID = _RES_OWNER;

  _U_NAME := null;
  select U_NAME into _U_NAME from DB.DBA.SYS_USERS where U_ID = _RES_OWNER;

  _WIKI_PATH := sprintf (\'/wiki/%s/%s\', _ClusterName, _LocalName);
  _WIKI_INSTANCE_PATH := sprintf (\'/wiki/%s\', _ClusterName);
  res := sprintf (\'<span><img src="%s" />Wiki <a href="%s">%s</a> <a href="%s">%s</a> <a href="%s">%s</a>\',
           WA_SEARCH_ADD_APATH (''images/icons/wiki_16.png''),
	   WA_SEARCH_ADD_APATH (WA_SEARCH_ADD_SID_IF_AVAILABLE (coalesce (_WIKI_PATH, \'#\'), _current_user_id)),
		coalesce (_TitleText, N\'#No Title#\'),
	   WA_SEARCH_ADD_APATH (WA_SEARCH_ADD_SID_IF_AVAILABLE (coalesce (_WIKI_INSTANCE_PATH, \'#\'), _current_user_id)),
		coalesce (_ClusterName, \'#No Title#\'),
           WA_SEARCH_ADD_APATH (
             WA_SEARCH_ADD_SID_IF_AVAILABLE ( sprintf (\'uhome.vspx?ufname=%U\', _U_NAME), _current_user_id, \'&\')),
           coalesce (_WAUI_FULL_NAME, \'#No Name#\'));

  _content := coalesce (_RES_CONTENT, \'\');
  if (not isblob (_content))
    _content := cast (_content as varchar);
  _content := subseq (_content, 0, 200000);
  res := res || \'<br />\' || left (search_excerpt (words, _content), 900) || \'</span>\';

  return res;
}')
;

-- makes a SQL query for WA search over the DAV resources
-- Params :
--  search_dav : include the DAV resources in the mix
--  search_wiki : include the Wiki resouces in the mix
create function WA_SEARCH_DAV (in max_rows integer, in current_user_id integer,
   in str varchar, in tags_str varchar, in _words_vector varchar,
   in search_dav integer, in search_wiki integer) returns any
{
  declare ret varchar;

  declare sel_col varchar;
  declare wiki_installed integer;

  wiki_installed := case when DB.DBA.wa_vad_check ('wiki') is not null then 1 else 0 end;

  if (str is null and tags_str is null)
    {
      ret := sprintf (
	'SELECT RES_ID, RES_CONTENT, RES_FULL_PATH, RES_OWNER, RES_COL, 0 as _SCORE, RES_MOD_TIME as _DATE, %s as _WORDS_VECTOR FROM WS.WS.SYS_DAV_RES SDR \n',
        _words_vector);
    }
  else if (str is null)
    {
      ret := sprintf (
	'SELECT RES_ID, RES_CONTENT, RES_FULL_PATH, RES_OWNER, RES_COL, SCORE as _SCORE, RES_MOD_TIME as _DATE, %s as _WORDS_VECTOR \n' ||
        ' FROM WS.WS.SYS_DAV_RES, WS.WS.SYS_DAV_TAG \n' ||
	' WHERE \n' ||
	'  contains (DT_TAGS, \n' ||
	'    ''[__lang "x-ViDoc" __enc "UTF-8"] (%S) AND ((UID%d) OR (UID%d))'' \n' ||
	'--      ,OFFBAND,DT_RES_ID \n' ||
	'  ) \n' ||
        '  and DT_RES_ID = RES_ID',
        _words_vector,
        tags_str,
	current_user_id,
	http_nobody_uid());
    }
  else
    {
      ret := sprintf(
	'SELECT RES_ID, RES_CONTENT, RES_FULL_PATH, RES_OWNER, RES_COL, SCORE as _SCORE, RES_MOD_TIME as _DATE, %s as _WORDS_VECTOR FROM WS.WS.SYS_DAV_RES SDR \n' ||
	' WHERE \n' ||
	'       contains (RES_CONTENT, ''[__lang "x-any" __enc "UTF-8"] %S'',descending) ' ||
	'   \n',
	_words_vector, str);

      if (tags_str is not null)
	ret := sprintf (
	  '%s and exists ( \n' ||
	  '  SELECT 1 FROM WS.WS.SYS_DAV_TAG \n' ||
	  '    WHERE \n' ||
	  '      contains (DT_TAGS, \n' ||
	  '        ''[__lang "x-ViDoc" __enc "UTF-8"] (%S) AND ((UID%d) OR (UID%d))'' \n' ||
	  '--          ,OFFBAND,DT_RES_ID \n' ||
	  '      ) and DT_RES_ID = SDR.RES_ID) \n',
	  ret,
	  tags_str,
	  current_user_id,
	  http_nobody_uid());
    }

  if (search_dav and search_wiki)
    sel_col :=  sprintf (
         '  case \n' ||
         '    when (RES_COL in (select ColId from WV.WIKI.CLUSTERS)) \n' ||
         '      then WA_SEARCH_WIKI_GET_EXCERPT_HTML (%d, RES_ID, _WORDS_VECTOR, RES_CONTENT, RES_FULL_PATH, RES_OWNER) \n' ||
         '    else WA_SEARCH_DAV_GET_EXCERPT_HTML (%d, RES_ID, _WORDS_VECTOR, RES_CONTENT, RES_FULL_PATH) \n' ||
         '  end', current_user_id, current_user_id);
  else if (search_dav)
    sel_col :=  sprintf (
         '  WA_SEARCH_DAV_GET_EXCERPT_HTML (%d, RES_ID, _WORDS_VECTOR, RES_CONTENT, RES_FULL_PATH)',
	 current_user_id);
  else if (search_wiki)
    sel_col :=  sprintf (
         '  WA_SEARCH_WIKI_GET_EXCERPT_HTML (%d, RES_ID, _WORDS_VECTOR, RES_CONTENT, RES_FULL_PATH, RES_OWNER)',
	 current_user_id);
  else
    sel_col := ' null';
  ret := sprintf (
         'select top %d \n' ||
         '  %s AS EXCERPT, \n ' ||
         '  encode_base64 (serialize (vector (''DAV'', RES_ID))) as TAG_TABLE_FK, \n' ||
         '  _SCORE, \n' ||
         '  _DATE \n' ||
         ' from \n(\n%s\n) qry\n' ||
         ' where DAV_AUTHENTICATE (RES_ID, ''R'', ''1__'', NULL, NULL, %d) >= 0 \n',
    max_rows * (
	(case when search_dav <> 0 then 1 else 0 end) +
        (case when search_wiki <> 0 then 1 else 0 end)),
    sel_col, ret, current_user_id);

  -- currently the sorry way to distinguish Wiki from other DAV resources
  if (search_dav and not search_wiki and wiki_installed)
     ret := ret || ' and RES_COL not in (select ColId from WV.WIKI.CLUSTERS)';
  else if (search_wiki and not search_dav and wiki_installed)
     ret := ret || ' and RES_COL in (select ColId from WV.WIKI.CLUSTERS)';
  else if (not (search_wiki or search_dav))
     ret := ret || ' and 1 = 0';
  return ret;
}
;

-- creates a search excerpt for a enews.
-- see http://wiki.usnet.private:8791/twiki/bin/view/Main/VirtWASpecsRevisions#Advanced_Search for description
-- params : words : an array of search words (as returned by the FTI_MAKE_SEARCH_STRING_INNER
-- returns the XHTML fragment
--exec ('
wa_exec_no_error ('
create function WA_SEARCH_ENEWS_GET_EXCERPT_HTML (in _current_user_id integer, in _EFI_ID integer, in _EFI_FEED_ID integer, in _EFI_DOMAIN_ID integer,
	in words any) returns varchar
{
  declare _EFI_TITLE, _EF_TITLE, _EFI_DESCRIPTION varchar;
  declare res varchar;

  select
    ENEWS.WA.show_title (EFI_TITLE), EF_TITLE, ENEWS.WA.xml2string (ENEWS.WA.show_description(EFI_DESCRIPTION))
   into
    _EFI_TITLE, _EF_TITLE, _EFI_DESCRIPTION
  from ENEWS.WA.FEED_ITEM, ENEWS.WA.FEED where EFI_ID = _EFI_ID and EF_ID = EFI_FEED_ID;

  res := sprintf (\'<span><img src="%s" /> <a href="%s">%s</a> %s \',
           WA_SEARCH_ADD_APATH (''images/icons/enews_16.png''),
	   WA_SEARCH_ADD_APATH (WA_SEARCH_ADD_SID_IF_AVAILABLE (sprintf (\'/enews2/news.vspx?link=%d\', _EFI_ID), _current_user_id, \'&\')), _EFI_TITLE,
	   _EF_TITLE);

  res := res || \'<br />\' ||
     left (
       search_excerpt (
         words,
         subseq (coalesce (_EFI_DESCRIPTION, \'\'), 0, 200000)
       ),
       900)
     || \'</span>\';

  return res;
}')
;

-- makes a SQL query for WA search over the BLOG posts
create function WA_SEARCH_ENEWS (in max_rows integer, in current_user_id integer,
   in str varchar, in tags_str varchar, in _words_vector varchar) returns any
{
  declare ret varchar;

  --dbg_obj_print ('str=', str, 'tags_str:=', tags_str);
  if (str is null and tags_str is null)
    {
      ret := sprintf(
	'SELECT EFI_ID, EFI_FEED_ID, EFD.EFD_DOMAIN_ID, EFD.EFD_ID, 0 as _SCORE, EFI_LAST_UPDATE as _DATE \n' ||
	' FROM ENEWS.WA.FEED_ITEM EFI, ENEWS.WA.FEED_DOMAIN EFD \n' ||
	' WHERE \n' ||
	'   EFI_FEED_ID = EFD.EFD_FEED_ID'
	);
    }
  else if (str is null)
    {
      ret := sprintf(
	'SELECT EFI_ID, EFI_FEED_ID, EFD_DOMAIN_ID, EFD_ID, SCORE as _SCORE, EFI_LAST_UPDATE as _DATE \n' ||
        ' from ENEWS.WA.FEED_ITEM_DATA, ENEWS.WA.FEED_ITEM, ENEWS.WA.FEED_DOMAIN \n' ||
	' WHERE \n' ||
	'   contains (EFID_TAGS, \n' ||
	'    ''[__lang "x-ViDoc" __enc "UTF-8"] (%S) AND (("%da") OR ("%da"))'') \n' ||
	'   and EFI_FEED_ID = EFD_FEED_ID \n' ||
	'   and EFID_ITEM_ID = EFI_ID',
        tags_str,
        current_user_id,
        http_nobody_uid());

    }
  else
    {
      ret := sprintf(
	'SELECT EFI_ID, EFI_FEED_ID, EFD.EFD_DOMAIN_ID, EFD.EFD_ID, SCORE as _SCORE, EFI_LAST_UPDATE as _DATE \n' ||
	' FROM ENEWS.WA.FEED_ITEM EFI, ENEWS.WA.FEED_DOMAIN EFD \n' ||
	' WHERE \n' ||
	'   contains (EFI_DESCRIPTION, ''[__lang "x-any" __enc "UTF-8"] %S'',descending \n' ||
	'--,OFFBAND,EFI_ID,OFFBAND,EFI_FEED_ID\n' ||
	'   ) \n' ||
	'   and EFI_FEED_ID = EFD.EFD_FEED_ID ',
	str);

      if (tags_str is not null)
	ret := sprintf (
	  '%s\n and exists ( \n' ||
	  '  SELECT 1 FROM ENEWS.WA.FEED_ITEM_DATA \n' ||
	  '    WHERE \n' ||
	  '      contains (EFID_TAGS, \n' ||
	  '        sprintf (''[__lang "x-ViDoc" __enc "UTF-8"] (%S) AND (("%da") OR ("%da")) AND ("%%di")'', \n' ||
	  '          EFI_ID))) \n',
	  ret,
	  tags_str,
	  current_user_id,
          http_nobody_uid());
      ret := ret || ' option (order) ';
    }

  ret := sprintf (
         'select EXCERPT, TAG_TABLE_FK, _SCORE, _DATE from (' ||
         'select top %d \n' ||
         '  WA_SEARCH_ENEWS_GET_EXCERPT_HTML (%d, EFI_ID, EFI_FEED_ID, EFD_DOMAIN_ID, %s) AS EXCERPT, \n' ||
         '  encode_base64 (serialize (vector (''ENEWS'', vector (EFI_ID, EFD_DOMAIN_ID)))) as TAG_TABLE_FK, \n' ||
         '  _SCORE, \n' ||
         '  _DATE \n' ||
         ' from \n(\n%s\n) qry, \nDB.DBA.WA_INSTANCE WAI \n' ||
         ' where \n' ||
         '  WAI.WAI_ID = qry.EFD_DOMAIN_ID \n' ||
         '  and (\n' ||
	 '    WAI.WAI_IS_PUBLIC > 0 OR \n' ||
	 '    exists (\n' ||
	 '      select 1 from DB.DBA.WA_MEMBER \n' ||
	 '        where WAM_INST = WAI.WAI_NAME \n' ||
	 '         and WAM_USER = %d \n' ||
	 '         and WAM_MEMBER_TYPE >= 1 \n' ||
	 '         and (WAM_EXPIRES < now () or WAM_EXPIRES is null))) \n' ||
	 'option (order)) x',
    max_rows, current_user_id, _words_vector, ret, current_user_id);

  return ret;
}
;

-- check if the _u_id user can join the instance _inst
-- returns : boolean (0|1)
create procedure WA_USER_CAN_JOIN_INSTANCE (
	in _u_id integer,
	in _inst varchar)
returns integer
{
  declare res integer;

  res := 1;

  if (exists(select 1 from DB.DBA.WA_MEMBER where WAM_USER = _u_id and WAM_INST = _inst))
    res := 0;
  else if (exists (select 1 from DB.DBA.WA_INSTANCE where WAI_NAME = _inst and WAI_MEMBER_MODEL in (1, 2)))
    res := 0;
  return res;
}
;


create function WA_SEARCH_APP_GET_EXCERPT_HTML (
        in current_user_id integer,
	in words any,
	in _WAI_NAME varchar,
	in _WAI_DESCRIPTION varchar,
	in _WAI_TYPE_NAME varchar,
        in _WAI_HOME_URL varchar,
        in _WAI_ID integer) returns varchar
{
  declare res varchar;

  res := sprintf (
    '<span><img src="%s"/> <a href="%s">%s</a> %s ',
       WA_SEARCH_ADD_APATH ('images/icons/apps_16.png'),
       WA_SEARCH_ADD_APATH (WA_SEARCH_ADD_SID_IF_AVAILABLE (coalesce (_WAI_HOME_URL, '#'), current_user_id)),
       _WAI_NAME,
       _WAI_TYPE_NAME);

  if (WA_USER_CAN_JOIN_INSTANCE (current_user_id, _WAI_NAME))
    res := res || sprintf ('<a href="%s"><img src="%s" border="0" alt="Join" title="Join"/>&nbsp;Join</a>',
         WA_SEARCH_ADD_APATH (WA_SEARCH_ADD_SID_IF_AVAILABLE (
		sprintf ('join.vspx?wai_id=%d', _WAI_ID), current_user_id)),
         WA_SEARCH_ADD_APATH ('images/icons/add_16.png'));

  res := res || sprintf ('<br>%s</span>',
       left (
         search_excerpt (
           words,
           subseq (coalesce (_WAI_DESCRIPTION, ''), 0, 200000)
         ),
         900));

  return res;
}
;

create function WA_SEARCH_APP (in max_rows integer, in current_user_id integer,
   in str varchar, in _words_vector varchar) returns varchar
{
  declare ret varchar;

  if (str is null)
    {
      ret := sprintf (
	     'select top %d \n' ||
	     '  WA_SEARCH_APP_GET_EXCERPT_HTML (%d, %s, WAI_NAME, WAI_DESCRIPTION, \n' ||
	     '         WAI_TYPE_NAME, DB.DBA.WA_INSTANCE.WAI_INST.wa_home_url (), WAI_ID) AS EXCERPT, \n' ||
	     '  encode_base64 (serialize (vector (''APP''))) as TAG_TABLE_FK, \n' ||
	     '  0 as _SCORE, \n' ||
	     '  WAI_MODIFIED as _DATE\n' ||
	     ' from DB.DBA.WA_INSTANCE\n' ||
	     ' where \n' ||
	     '    WAI_IS_PUBLIC > 0 OR \n' ||
	     '    exists (\n' ||
	     '      select 1 from DB.DBA.WA_MEMBER \n' ||
	     '        where WAM_INST = WAI_NAME \n' ||
	     '         and WAM_USER = %d \n' ||
	     '         and WAM_MEMBER_TYPE >= 1 \n' ||
	     '         and (WAM_EXPIRES < now () or WAM_EXPIRES is null) \n' ||
	     '    )',
	max_rows, current_user_id, _words_vector, current_user_id);
    }
  else
    {
      ret := sprintf (
	     'select top %d \n' ||
	     '  WA_SEARCH_APP_GET_EXCERPT_HTML (%d, %s, WAI_NAME, WAI_DESCRIPTION, \n' ||
	     '         WAI_TYPE_NAME, DB.DBA.WA_INSTANCE.WAI_INST.wa_home_url (), WAI_ID) AS EXCERPT, \n' ||
	     '  encode_base64 (serialize (vector (''APP''))) as TAG_TABLE_FK, \n' ||
	     '  SCORE as _SCORE, \n' ||
	     '  WAI_MODIFIED as _DATE\n' ||
	     ' from DB.DBA.WA_INSTANCE\n' ||
	     ' where \n' ||
	     '  contains (WAI_DESCRIPTION, ''[__lang "x-ViDoc" __enc "UTF-8"] %S'') \n' ||
	     '  and (\n' ||
	     '    WAI_IS_PUBLIC > 0 OR \n' ||
	     '    exists (\n' ||
	     '      select 1 from DB.DBA.WA_MEMBER \n' ||
	     '        where WAM_INST = WAI_NAME \n' ||
	     '         and WAM_USER = %d \n' ||
	     '         and WAM_MEMBER_TYPE >= 1 \n' ||
	     '         and (WAM_EXPIRES < now () or WAM_EXPIRES is null) \n' ||
	     '    ) \n' ||
	     '  )',
	max_rows, current_user_id, _words_vector, str, current_user_id);
    }

  return ret;
}
;

--exec('
wa_exec_no_error('
create function WA_SEARCH_OMAIL_GET_EXCERPT_HTML (
        in current_user_id integer,
	in words any,
        in _MSG_ID integer,
        in _DOMAIN_ID integer,
        in _TDATA any,
        in _SUBJECT varchar,
        in _FOLDER_ID integer) returns varchar
{
  declare res varchar;

  declare _U_NAME varchar;
  declare _NAME varchar;

  select U_NAME into _U_NAME from DB.DBA.SYS_USERS where U_ID = current_user_id;
  select NAME into _NAME from OMAIL.WA.FOLDERS where FOLDER_ID = _FOLDER_ID;

  res := sprintf (
    ''<span><img src="%s"/> %s / %s : %s<br>%s</span>'',
       WA_SEARCH_ADD_APATH (''images/icons/mail_16.png''),
       _U_NAME,
       _NAME,
       _SUBJECT,
       _TDATA);
       --search_excerpt (words, subseq (coalesce (_TDATA, ''''), 0, 200000)));
  return res;
}
')
;

create function WA_SEARCH_OMAIL_AGG_init (inout _agg any)
{
  _agg := null; -- The "accumulator" is a string session. Initially it is empty.
}
;

create function WA_SEARCH_OMAIL_AGG_acc (
  inout _agg any,		-- The first parameter is used for passing "accumulator" value.
  in _val varchar,	-- Second parameter gets the value passed by first parameter of aggregate call.
  in words any
  )	-- Third parameter gets the value passed by second parameter of aggregate call.
{
  if (_val is not null and _agg is null)	-- Attributes with NULL names should not affect the result.
    {
       _agg := left (search_excerpt (words, subseq (coalesce (_val, ''), 0, 200000)), 900);
    }
}
;

create function WA_SEARCH_OMAIL_AGG_final (inout _agg any) returns varchar
{
  return coalesce (_agg, '');
}
;

create aggregate WA_SEARCH_OMAIL_AGG (in _val varchar, in words any) returns varchar
  from WA_SEARCH_OMAIL_AGG_init, WA_SEARCH_OMAIL_AGG_acc, WA_SEARCH_OMAIL_AGG_final;


create function WA_SEARCH_OMAIL (in max_rows integer, in current_user_id integer,
   in str varchar, in _words_vector varchar) returns varchar
{
  declare ret varchar;

  if (str is null)
    {
      ret := sprintf (
	     'select top %d \n' ||
	     '  WA_SEARCH_OMAIL_GET_EXCERPT_HTML (q.USER_ID, %s, \n' ||
	     '     q.MSG_ID, q.DOMAIN_ID, _TDATA, M.SUBJECT, M.FOLDER_ID) AS EXCERPT, \n' ||
	     '  encode_base64 (serialize (vector (''OMAIL''))) as TAG_TABLE_FK, \n' ||
	     '  _SCORE, \n' ||
	     '  M.RCV_DATE as _DATE \n' ||
	     ' from OMAIL.WA.MESSAGES M, (\n' ||
	     ' select \n' ||
	     '   MP.DOMAIN_ID, \n' ||
	     '   MP.USER_ID, \n' ||
	     '   MP.MSG_ID, \n' ||
	     '   WA_SEARCH_OMAIL_AGG (TDATA, %s) as _TDATA long varchar, \n' ||
	     '   0 as _SCORE \n' ||
	     ' from OMAIL.WA.MSG_PARTS MP\n' ||
	     ' where \n' ||
	     '  MP.USER_ID = %d\n' ||
	     '  group by MP.DOMAIN_ID, MP.USER_ID, MP.MSG_ID) q \n' ||
	     ' where M.MSG_ID = q.MSG_ID and M.USER_ID = q.USER_ID and M.DOMAIN_ID = q.DOMAIN_ID',
	max_rows, _words_vector, _words_vector, current_user_id);
    }
  else
    {
      ret := sprintf (
	     'select top %d \n' ||
	     '  WA_SEARCH_OMAIL_GET_EXCERPT_HTML (q.USER_ID, %s, \n' ||
	     '     q.MSG_ID, q.DOMAIN_ID, _TDATA, M.SUBJECT, M.FOLDER_ID) AS EXCERPT, \n' ||
	     '  encode_base64 (serialize (vector (''OMAIL''))) as TAG_TABLE_FK, \n' ||
	     '  _SCORE, \n' ||
	     '  M.RCV_DATE as _DATE \n' ||
	     ' from OMAIL.WA.MESSAGES M, (\n' ||
	     ' select \n' ||
	     '   MP.DOMAIN_ID, \n' ||
	     '   MP.USER_ID, \n' ||
	     '   MP.MSG_ID, \n' ||
	     '   WA_SEARCH_OMAIL_AGG (TDATA, %s) as _TDATA long varchar, \n' ||
	     '   MAX(SCORE) as _SCORE \n' ||
	     ' from OMAIL.WA.MSG_PARTS MP\n' ||
	     ' where \n' ||
	     '  contains (MP.TDATA, ''[__lang "x-ViDoc" __enc "UTF-8"] %S'') \n' ||
	     '  and MP.USER_ID = %d\n' ||
	     '  group by MP.DOMAIN_ID, MP.USER_ID, MP.MSG_ID) q \n' ||
	     ' where M.MSG_ID = q.MSG_ID and M.USER_ID = q.USER_ID and M.DOMAIN_ID = q.DOMAIN_ID',
	max_rows, _words_vector, _words_vector, str, current_user_id);
    }

  return ret;
}
;

create procedure WA_SEARCH_CONSTRUCT_QUERY (in current_user_id integer, in qry nvarchar, in q_tags nvarchar,
	in search_people integer, in search_news integer, in search_blogs integer, in search_wikis integer,
        in search_dav integer, in search_apps integer, in search_omail integer, in sort_by_score integer,
        in max_rows integer, in tag_is_qry int, out tags_vector any)
returns varchar
{
  declare ret varchar;

  if (current_user_id is null)
    current_user_id := http_nobody_uid ();
  ret := '';

  declare str, tags_str, _words_vector varchar;

--  dbg_obj_print ('max_rows=', max_rows);

  WA_SEARCH_PROCESS_PARAMS (qry, q_tags, tag_is_qry,
	str, tags_str, _words_vector, tags_vector);

  if (search_people)
    {
      if (ret <> '')
        ret := ret || '\n\nUNION ALL\n\n';
      ret := ret || WA_SEARCH_USER (max_rows, current_user_id, str, tags_str, _words_vector);
    }
  if (search_news and DB.DBA.wa_vad_check ('enews2') is not null)
    {
      if (ret <> '')
        ret := ret || '\n\nUNION ALL\n\n';
      ret := ret || WA_SEARCH_ENEWS (max_rows, current_user_id, str, tags_str, _words_vector);
    }
  if (search_blogs and DB.DBA.wa_vad_check ('blog2') is not null)
    {
      if (ret <> '')
        ret := ret || '\n\nUNION ALL\n\n';
      ret := ret || WA_SEARCH_BLOG (max_rows, current_user_id, str, tags_str, _words_vector);
    }

  if (DB.DBA.wa_vad_check ('wiki') is null)
    search_wikis := 0;
  if (search_wikis or search_dav)
    {
      if (ret <> '')
        ret := ret || '\n\nUNION ALL\n\n';
      ret := ret || WA_SEARCH_DAV (max_rows, current_user_id, str, tags_str, _words_vector,
			search_dav, search_wikis);
    }
  if (search_apps
	and (not is_empty_or_null (str))
	and is_empty_or_null (tags_str))
    {
      if (ret <> '')
        ret := ret || '\n\nUNION ALL\n\n';
      ret := ret || WA_SEARCH_APP (max_rows, current_user_id, str, _words_vector);
    }
  if (search_omail
	and (not is_empty_or_null (str))
	and is_empty_or_null (tags_str))
    {
      if (ret <> '')
        ret := ret || '\n\nUNION ALL\n\n';
      ret := ret || WA_SEARCH_OMAIL (max_rows, current_user_id, str, _words_vector);
    }
  if (ret <> '')
    ret := sprintf ('select top %d EXCERPT, TAG_TABLE_FK, _SCORE, _DATE from \n(\n%s ORDER BY %s desc\n) q',
       max_rows, ret, case when sort_by_score <> 0 then  '_SCORE' else '_DATE' end);

--  dbg_obj_print (ret);
  return ret;
}
;

create procedure WA_SEARCH_ADD_TAG (
	in current_user_id integer,
	in upd_type varchar,
	inout pk_array any,
	in new_tag_expr nvarchar)
{
  if (current_user_id is null)
    current_user_id := http_nobody_uid ();

  if (upd_type = 'USER')
    WA_SEARCH_ADD_USER_TAG (current_user_id, pk_array, new_tag_expr);
  else if (upd_type = 'BLOG')
    WA_SEARCH_ADD_BLOG_TAG (current_user_id, pk_array, new_tag_expr);
  else if (upd_type = 'DAV')
    WA_SEARCH_ADD_DAV_TAG (current_user_id, pk_array, new_tag_expr);
  else if (upd_type = 'ENEWS')
    WA_SEARCH_ADD_ENEWS_TAG (current_user_id, pk_array, new_tag_expr);
  else
    signal ('22023', sprintf ('Unknown type tag %s in WA_SEARCH_ADD_TAG', upd_type));
}
;

create procedure WA_SEARCH_ADD_USER_TAG (
	in current_user_id integer,
	inout pk_array any,
	in new_tag_expr nvarchar)
{
  declare _tags varchar;
  declare _tag_id integer;

  _tag_id := cast (pk_array as integer);

  _tags := WA_USER_TAGS_GET (current_user_id,_tag_id);
  if (_tags <> '')
    _tags := _tags || ',' || charset_recode (new_tag_expr, '_WIDE_', 'UTF-8');
  else
    _tags := charset_recode (new_tag_expr, '_WIDE_', 'UTF-8');

  _tags := WA_TAG_PREPARE (_tags);
  if (not WA_VALIDATE_TAGS (_tags))
    signal ('22023', 'Invalid new tags string : ' || _tags);

  WA_USER_TAG_SET (current_user_id, _tag_id, _tags);
}
;

wa_exec_no_error('
create procedure WA_SEARCH_ADD_BLOG_TAG (
	in current_user_id integer,
	inout pk_array any,
	in new_tag_expr nvarchar)
{
  declare _tags varchar;
  declare _B_POST_ID, _B_BLOG_ID varchar;

  _B_BLOG_ID := cast (pk_array[0] as varchar);
  _B_POST_ID := cast (pk_array[1] as varchar);

  _tags := '''';
  declare cr cursor for
	select BT_TAGS from BLOG.DBA.BLOG_TAG
	  where BT_POST_ID = _B_POST_ID and BT_BLOG_ID = _B_BLOG_ID;

  declare exit handler for not found
    {
      _tags := charset_recode (new_tag_expr, ''_WIDE_'', ''UTF-8'');
      insert replacing BLOG.DBA.BLOG_TAG (BT_BLOG_ID, BT_POST_ID, BT_TAGS)
        values (_B_BLOG_ID, _B_POST_ID, _tags);
    };

  open cr (exclusive, prefetch 1);
  fetch cr into _tags;

  if (_tags <> '''')
    _tags := _tags || '','' || charset_recode (new_tag_expr, ''_WIDE_'', ''UTF-8'');
  else
    _tags := charset_recode (new_tag_expr, ''_WIDE_'', ''UTF-8'');
  update BLOG.DBA.BLOG_TAG set BT_TAGS = _tags where current of cr;

  close cr;
}')
;

create procedure WA_SEARCH_ADD_DAV_TAG (
	in current_user_id integer,
	inout pk_array any,
	in new_tag_expr nvarchar)
{
  declare _tags any;
  declare _res_id integer;

  _res_id := cast (pk_array as integer);

  _tags := DAV_TAG_LIST (_res_id, 'R', vector (current_user_id));
  if (isarray (_tags) and length (_tags) > 0)
    _tags := _tags[0][1];
  else
    _tags := '';

  if (_tags <> '')
    _tags := _tags || ',' || charset_recode (new_tag_expr, '_WIDE_', 'UTF-8');
  else
    _tags := charset_recode (new_tag_expr, '_WIDE_', 'UTF-8');

  DAV_TAG_SET (_res_id, 'R', current_user_id, _tags);
}
;

create procedure WA_SEARCH_ADD_ENEWS_TAG (
	in current_user_id integer,
	inout pk_array any,
	in new_tag_expr nvarchar)
{
  declare _tags any;
  declare _item_id, _domain_id integer;

  _item_id := cast (pk_array[0] as integer);
  _domain_id := cast (pk_array[1] as integer);

  _tags := ENEWS.WA.tags_account_item_select(_domain_id, current_user_id, _item_id);
  if (isstring (_tags) and _tags <> '')
    _tags := _tags || ',' || charset_recode (new_tag_expr, '_WIDE_', 'UTF-8');
  else
    _tags := charset_recode (new_tag_expr, '_WIDE_', 'UTF-8');

  ENEWS.WA.tags_account_item (current_user_id, _item_id, _tags);
}
;


create procedure WA_SEARCH_FILL_REL_TAGS (in current_user_id integer, in tags_vector any, out data any, out meta any)
{
  if (current_user_id is null)
    current_user_id := http_nobody_uid ();

  data := vector ();
  meta := vector ();

  if (tags_vector is null)
    return;

--  dbg_obj_print ('WA_SEARCH_FILL_REL_TAGS', current_user_id, tags_vector);
  foreach (varchar word in tags_vector) do
    {
      declare res any;
      declare _rel_tags_list varchar;
      declare qry varchar;

--      dbg_obj_print ('WA_SEARCH_FILL_REL_TAGS word=', word);
      qry :=
       ' select top 10 TR \n' ||
       '  from (\n' ||
       '    select top 10 TR_T1 as TR, TR_COUNT from WA_TAG_REL_INX where TR_T2 = ? \n' ||
       '   UNION ALL \n' ||
       '    select top 10 TR_T2 as TR, TR_COUNT from WA_TAG_REL_INX where TR_T1 = ? \n' ||
       '  ) qry\n' ||
       ' order by TR_COUNT desc';
--      dbg_obj_print ('WA_SEARCH_FILL_REL_TAGS qry=', qry);
      exec (qry,
       null, null, vector (word, word), 10, null, res);
      _rel_tags_list := '';
--      dbg_obj_print ('WA_SEARCH_FILL_REL_TAGS res=', res);
      foreach (any row in res) do
        {
          if (_rel_tags_list <> '')
            _rel_tags_list := _rel_tags_list || ', ';

          _rel_tags_list :=
	    _rel_tags_list ||
            '<a href=" ' ||
	    WA_SEARCH_ADD_SID_IF_AVAILABLE (
              sprintf ('search.vspx?q_tags=%U', row[0]),
              current_user_id, '&') ||
	    '">' || row[0] || '</a>';
        }
      if (_rel_tags_list <> '')
        data := vector_concat (data, vector (vector (word, _rel_tags_list)));
    }
}
;

-- calculates the distance between two points in either miles or km using spherical coordinates.
-- check http://jan.ucc.nau.edu/~cvm/latlongdist.html
-- lat1/lng1 coordinates in degrees of point1
-- lat2/lng2 coordinates in degrees of point2
-- in_miles : boolean to return the result in statute miles (not in kilometers).
-- returns the resulting distance
create function WA_SEARCH_DISTANCE
(
  in lat1 real,
  in lng1 real,
  in lat2 real,
  in lng2 real,
  in in_miles smallint := 0)
returns real
{
  declare a1,b1,a2,b2,r, ret double precision;

  if (lat1 is null or lat2 is null or lng1 is null or lng2 is null)
    return null;
  a1 := radians (lat1);
  b1 := radians (lng1);
  a2 := radians (lat2);
  b2 := radians (lng2);

  if (in_miles)
   r := 3963.1; -- statute miles
  else
   r := 6378; -- km
  ret := acos (
         cos (a1) * cos (b1) * cos (a2) * cos (b2) +
         cos (a1) * sin (b1) * cos (a2) * sin (b2) +
         sin (a1) * sin(a2)
        ) * r;
  return cast (ret as real);
}
;

-- TODO: check the visibility (permissions) of the users !!!
create function WA_SEARCH_CONTACTS (
  in max_rows integer,
  in current_user_id integer,
  in nqry nvarchar,
  in nq_tags nvarchar,
  in nfirst_name nvarchar,
  in nlast_name nvarchar,
  in within_friends smallint, -- 0:all, 1:friends, 2: friends of friends
  in _wai_name varchar,
  in within_distance real,
  in within_distance_unit smallint, -- 0 : km, 1 miles
  in within_distance_lat real,
  in within_distance_lng real,
  in oby smallint, -- 0: name, 1:relevance, 2:distance, 3:time
  in current_user_name varchar,
  in is_for_result integer,
  out tags_vector varchar
) returns varchar
{
  declare ret varchar;
  declare str, tags_str, _words_vector, first_name, last_name varchar;

  declare _WAUT_CONDS varchar;
  declare _WAUT_DISTANCE varchar;

  if (current_user_id is null)
    current_user_id := http_nobody_uid ();

  WA_SEARCH_PROCESS_PARAMS (nqry, nq_tags, 0,
	str, tags_str, _words_vector, tags_vector);

  if (within_distance_lat is not null and within_distance_lng is not null and within_distance_unit is not null)
    _WAUT_DISTANCE := sprintf ('WA_SEARCH_DISTANCE (%.6f, %.6f, WAUI_LAT, WAUI_LNG, %d)',
	   within_distance_lat,
	   within_distance_lng,
	   within_distance_unit);
  else
    _WAUT_DISTANCE := NULL;

  -- TODO: devise better way to store unicode names
  first_name := cast (nfirst_name as varchar);
  last_name := cast (nlast_name as varchar);

  _WAUT_CONDS := '';

  if ((oby = 2 and _WAUT_DISTANCE is not null) or not is_for_result)
    _WAUT_CONDS := _WAUT_CONDS || ' and (WAUI_LAT is not null and WAUI_LNG is not null)\n';

  if (length (first_name))
    _WAUT_CONDS := _WAUT_CONDS || sprintf (' and lower(WAUI_FIRST_NAME) like lower(''%S'')\n', first_name);
  if (length (last_name))
    _WAUT_CONDS := _WAUT_CONDS || sprintf (' and lower(WAUI_LAST_NAME) like lower(''%S'')\n', last_name);
  if (within_distance is not null and _WAUT_DISTANCE is not null)
    _WAUT_CONDS := _WAUT_CONDS || sprintf (' and %s <= %.6f\n', _WAUT_DISTANCE, within_distance);
  if (length (_wai_name))
    _WAUT_CONDS := _WAUT_CONDS ||
	sprintf (
	  ' and exists (\n' ||
          '   select 1 from DB.DBA.WA_MEMBER \n' ||
          '    where \n' ||
          '      WAM_INST = ''%S'' \n' ||
	  '            and WAM_USER = WAUI_U_ID \n' ||
	  '            and WAM_MEMBER_TYPE >= 1 \n' ||
	  '            and (WAM_EXPIRES < now () or WAM_EXPIRES is null) \n' ||
          ' )\n',
          _wai_name);
  if (within_friends is not null and within_friends > 0)
    {
      if (within_friends = 1)
        { -- friends
          _WAUT_CONDS := _WAUT_CONDS || sprintf (
           ' and (exists (select 1 from (\n' ||
           '   select 1 as x from DB.DBA.sn_related, DB.DBA.sn_entity sne_from, DB.DBA.sn_entity sne_to \n' ||
           '     where \n' ||
           '       snr_to = sne_to.sne_id and snr_from = sne_from.sne_id and \n' ||
           '       sne_from.sne_name = U_NAME and sne_to.sne_name = ''%S'' \n' ||
           '   union all \n' ||
           '   select 1 as x from DB.DBA.sn_related, DB.DBA.sn_entity sne_from, DB.DBA.sn_entity sne_to \n' ||
           '     where \n' ||
           '       snr_to = sne_to.sne_id and snr_from = sne_from.sne_id and \n' ||
           '       sne_to.sne_name = U_NAME and sne_from.sne_name = ''%S'' \n' ||
           ' ) x) or U_NAME = ''%S'')\n',
           current_user_name, current_user_name, current_user_name);
        }
      else if (within_friends = 2)
        { -- friends of friends
          _WAUT_CONDS := _WAUT_CONDS || sprintf (
           ' and exists (select 1 from (\n' ||
           '   select 1 as x \n' ||
           '    from \n' ||
           '     DB.DBA.sn_related sn1, \n' ||
           '     DB.DBA.sn_related sn2, \n' ||
           '     DB.DBA.sn_entity sne1, \n' ||
           '     DB.DBA.sn_entity sne2 \n' ||
           '    where \n' ||
           '     sn1.snr_from = sne1.sne_id and sn2.snr_to = sne2.sne_id and \n' ||
           '     sne1.sne_name = U_NAME and sn1.snr_to = sn2.snr_from and sne2.sne_name = ''%S''\n' ||
           '   union all \n' ||
           '   select 1 as x \n' ||
           '    from \n' ||
           '     DB.DBA.sn_related sn1, \n' ||
           '     DB.DBA.sn_related sn2, \n' ||
           '     DB.DBA.sn_entity sne1, \n' ||
           '     DB.DBA.sn_entity sne2 \n' ||
           '    where \n' ||
           '     sn1.snr_from = sne1.sne_id and sn2.snr_from = sne2.sne_id and \n' ||
           '     sne1.sne_name = U_NAME and sn1.snr_to = sn2.snr_to and sne2.sne_name = ''%S'' \n' ||
           '   union all \n' ||
           '   select 1 as x \n' ||
           '    from \n' ||
           '     DB.DBA.sn_related sn1, \n' ||
           '     DB.DBA.sn_related sn2, \n' ||
           '     DB.DBA.sn_entity sne1, \n' ||
           '     DB.DBA.sn_entity sne2 \n' ||
           '    where \n' ||
           '     sn1.snr_to = sne1.sne_id and sn2.snr_to = sne2.sne_id and \n' ||
           '     sne1.sne_name = U_NAME and sn1.snr_from = sn2.snr_from and sne2.sne_name = ''%S'' \n' ||
           '   union all \n' ||
           '   select 1 as x \n' ||
           '    from \n' ||
           '     DB.DBA.sn_related sn1, \n' ||
           '     DB.DBA.sn_related sn2, \n' ||
           '     DB.DBA.sn_entity sne1, \n' ||
           '     DB.DBA.sn_entity sne2 \n' ||
           '    where \n' ||
           '     sn1.snr_to = sne1.sne_id and sn2.snr_from = sne2.sne_id and \n' ||
           '     sne1.sne_name = U_NAME and sn1.snr_from = sn2.snr_to and sne2.sne_name = ''%S'' \n' ||
           ' ) x)\n',
           current_user_name, current_user_name, current_user_name, current_user_name);
        }
    }


  ret := WA_SEARCH_USER_BASE (max_rows, current_user_id, str, tags_str, _words_vector);

  ret := sprintf (
	 'select top %d \n' ||
	 '  WA_SEARCH_USER_GET_EXCERPT_HTML (%d, %s, WAUT_U_ID, WAUT_TEXT, WAUI_FULL_NAME, U_NAME, WAUI_PHOTO_URL, U_E_MAIL, %d) AS EXCERPT, \n' ||
	 '  encode_base64 (serialize (vector (''USER'', WAUT_U_ID))) as TAG_TABLE_FK, \n' ||
	 '  _SCORE, \n' ||
	 '  U_LOGIN_TIME as _DATE, \n' ||
	 '  WA_SEARCH_ADD_APATH ( \n' ||
         '   WA_SEARCH_ADD_SID_IF_AVAILABLE ( \n' ||
         '    sprintf (''uhome.vspx?ufname=%%U'', U_NAME), %d, ''&'')) as _URL, \n' ||
	 '  WAUI_LAT as _LAT, \n' ||
	 '  WAUI_LNG as _LNG, \n' ||
	 '  WAUI_U_ID as _KEY_VAL \n' ||
	 ' from \n(\n%s\n) qry, DB.DBA.WA_USER_INFO, DB.DBA.SYS_USERS, DB.DBA.sn_person \n' ||
         ' where \n' ||
         '  WAUT_U_ID = WAUI_U_ID  and WAUI_SEARCHABLE = 1\n' ||
         '  and U_NAME = sne_name\n' ||
         '  and WAUT_U_ID = U_ID\n' ||
         ' %s\n'
         ,
    max_rows, current_user_id, _words_vector, is_for_result, current_user_id, ret, _WAUT_CONDS
    );

    if (is_for_result)
      { -- maps don't care about the ordering, so spare the temp table sort
         ret := ret || sprintf (
         ' ORDER BY %s\n',
	 case
	   when oby = 0 then 'WAUI_FULL_NAME'
	   when oby = 1 then '_SCORE'
	   when oby = 2 and _WAUT_DISTANCE is not null then _WAUT_DISTANCE
	   when 3 then 'U_LOGIN_TIME'
	   else '_SCORE'
	 end);
      }
  --dbg_obj_print (ret);
  return ret;
}
;

update WA_USER_INFO
  set WAUI_PHOTO_URL = NULL
where WAUI_PHOTO_URL is not null and length (WAUI_PHOTO_URL) = 0
;

update WA_USER_INFO set
  WAUI_PHOTO_URL =
    DAV_HOME_DIR ((select U_NAME from SYS_USERS where U_ID = WAUI_U_ID))||'/wa/images/'||WAUI_PHOTO_URL
where WAUI_PHOTO_URL is not null and blob_to_string (WAUI_PHOTO_URL) not like '/%'
;

create function WA_SEARCH_CHECK_FT_QUERY (in text varchar, in is_tags integer := 0) returns varchar
{
  declare exit handler for sqlstate '*' {
--      dbg_obj_print ('validate for ', text, 'failed :', __SQL_MESSAGE);
      return __SQL_MESSAGE;
  };

  if (length (text) > 0)
    {
      if (is_tags)
        text := WS.WS.DAV_TAG_NORMALIZE (text);
      vt_parse (FTI_MAKE_SEARCH_STRING (text));
    }

  return null;
}
;


create procedure  WA_USER_TAG_FT_UPGRADE ()
{
  if (registry_get ('__WA_USER_TAG_FT_UPGRADE') = 'done')
    return;
  exec ('drop table WA_USER_TAG_WAUTG_TAGS_WORDS');
  DB.DBA.vt_create_text_index ('WA_USER_TAG', 'WAUTG_TAGS', 'WAUTG_FT_ID', 2, 0, vector ('WAUTG_TAG_ID', 'WAUTG_U_ID'), 1, 'x-ViDoc', 'UTF-8');

  registry_set ('__WA_USER_TAG_FT_UPGRADE', 'done');
}
;

WA_USER_TAG_FT_UPGRADE ()
;


create procedure WA_SEARCH_FOAF (in sne any, in uids any)
{
  declare _u_name, _u_full_name, arr varchar;
  arr := split_and_decode (uids, 0, '\0\0,');
  result_names (_u_name, _u_full_name);
  foreach (any uid in arr) do
    {
      whenever not found goto nf;
      select u_name, u_full_name into _u_name, _u_full_name from SYS_USERS where U_ID = uid;
      result (_u_name, _u_full_name);
      nf:;
    }
};


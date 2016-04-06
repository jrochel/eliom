(* Ocsigen
 * http://www.ocsigen.org
 * Copyright (C) 2007 Vincent Balat
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, with linking exception;
 * either version 2.1 of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
 *)

module type S_types = sig

  include module type of Eliom_service_types

  type att
  type non_att

  type 'a attached_info =
    | Attached : att -> att attached_info
    | Nonattached : non_att -> non_att attached_info

  (** Type of services.
      - ['get] is the type of GET parameters expected by the service.
      - ['post] is the type of POST parameters expected by the service.
      - ['meth] the HTTP method
      - ['attached] attached or non-attached
      - ['co] co-service or regular service
      - ['ext] external or internal
      - ['reg]: possible to register a handler on this service
      - ['tipo] the type paremeter of subtype {!suff} states the kind
        of parameters it uses: suffix or not.
      - ['gn] is the type of GET parameters names. See
        {!Eliom_parameter.param_name} and form generation functions
        (e. g. {!Eliom_content.Html5.D.get_form}).
      - ['pn] is the type of POST parameters names. See
        {!Eliom_parameter.param_name} and form generation functions
        (e. g. {!Eliom_content.Html5.D.post_form}).
      - [ 'ret] is an information on what the service returns.
        See {!Eliom_registration.kind}. *)
  type ('get, 'post, 'meth, 'attached, 'co, 'ext, 'reg,
        +'tipo, 'gn, 'pn, +'ret) service
    constraint 'tipo = [< `WithSuffix | `WithoutSuffix ]

end

module type S = sig

  include S_types

  (** {2 Definitions of services}

      {e Warning: These functions must be called when the site
      information is available, that is, either during a request or
      during the initialisation phase of the site.  Otherwise, it will
      raise the exception
      {!Eliom_common.Eliom_site_information_not_available}.  If you
      are using static linking, you must delay the call to this
      function until the configuration file is read, using
      {!Eliom_service.register_eliom_module}. Otherwise you will also
      get this exception.}  *)

  (** The function [service m ~rt ()] creates a {!service} identified
      as per m. The parameter [~rt] is used to constrain the type
      parameter ['rt] of the service.

      If the optional parameter [~https:true] is given, all links
      towards that service will use https. By default, links will keep
      the current protocol.

      The optional parameter [~priority] allows one to change the
      priority order between service that shares the same path. The
      default priority is 0 ; if you want the service to be tried
      before (resp. after) other services, put a higher (resp. lower)
      priority.

      If the optional parameter [~keep_nl_params:`Persistent]
      (resp. [~keep_nl_params:`All]) is given, all links towards that
      service will keep persistent (resp. all) non localized GET
      parameters of the current service. The default is [`None]. See
      the eliom manual for more information about {% <<a_manual
      chapter="params" fragment="nonlocalizedparameters"|non localized
      parameters>>%}.  *)
  val service :
    ?https:bool ->
    ?keep_nl_params:[ `All | `Persistent | `None ] ->
    ?priority:int ->
    path:Eliom_lib.Url.path ->
    rt:('rt, _) rt ->
    meth:('m, 'gp, 'gn, 'pp, 'pn, [`WithoutSuffix], _, _) meth ->
    unit ->
    ('gp, 'pp, 'm, att, non_co, non_ext, reg, [`WithoutSuffix],
     'gn, 'pn, 'rt) service
  (* FIXME ^^^ : WithoutSuffix *)

  val coservice :
    ?name: string ->
    ?csrf_safe: bool ->
    ?csrf_scope: [< Eliom_common.user_scope] ->
    ?csrf_secure: bool ->
    ?max_use:int ->
    ?timeout:float ->
    ?https:bool ->
    ?keep_nl_params:[ `All | `Persistent | `None ] ->
    ?priority:int ->
    rt:('rt, _) rt ->
    meth:('m, 'gp, 'gn, 'pp, 'pn, [ `WithoutSuffix ], 'mf, unit) meth ->
    fallback:
      (unit, unit, 'mf, att, non_co, non_ext, reg,
       [ `WithoutSuffix ], unit, unit, 'rt) service ->
    unit ->
    ('gp, 'pp, 'm, att, co, non_ext, reg,
     [ `WithoutSuffix ], 'gn, 'pn, 'rt) service

  (** {3 Non attached coservices} *)

  (** The function [coservice' ~get_param] creates a {% <<a_manual
      chapter="services"
      fragment="non-attached_coservices"|non-attached coservice>>%}.

      The GET parameters of [coservice'] couldn't contain a suffix
      parameter.

      See {!service} for a description of the optional [~https], [~rt]
      and [~keep_nl_params] parameters ; see {!coservice} for others
      optional parameters.  *)
  val coservice' :
    ?name:string ->
    ?csrf_safe: bool ->
    ?csrf_scope: [< Eliom_common.user_scope] ->
    ?csrf_secure: bool ->
    ?max_use:int ->
    ?timeout:float ->
    ?https:bool ->
    ?keep_nl_params:[ `All | `Persistent | `None ] ->
    rt:('rt, _) rt ->
    meth:('m, 'gp, 'gn, 'pp, 'pn, [ `WithoutSuffix ], 'mf, unit) meth ->
    unit ->
    ('gp, 'pp, 'm, non_att, co, non_ext, reg,
     [`WithoutSuffix], 'gn, 'pn, 'rt) service

  (** {2 External services} *)

  (** The function [external_service ~prefix ~path ~get_params ()]
      creates a service for an external web site, that will use GET
      method and requires [get_params] as parameters. This allows one to
      creates links or forms towards other Web sites using Eliom's
      syntax.

      The parameter labelled [~path] is the URL path. Each element of
      the list will be URL-encoded.

      The parameter labelled [~prefix] contains all what you want to put
      before the path. It usually starts with "http://" plus the name of
      the server. The prefix is not URL encoded.

      The whole URL is constructed from the prefix, the path and GET
      parameters. Hence, an empty prefix can be used to make a link to
      another site of the same server.

      See {!val:service} for a description of the optional
      [~keep_nl_params] and [~rt] parameters.  *)
  val external_service :
    prefix: string ->
    path:Eliom_lib.Url.path ->
    ?keep_nl_params:[ `All | `Persistent | `None ] ->
    rt:('rt, ext) rt ->
    meth:('m, 'gp, 'gn, 'pp, 'pn, [ `WithoutSuffix ], 'mf, _) meth ->
    unit ->
    ('gp, 'pp, 'm, att, non_co, ext, non_reg,
     [ `WithoutSuffix ], 'gn, 'pn, 'rt) service

  (** {2 Predefined services} *)

  (** {3 Void non-attached coservices} *)

  (** The service [void_coservice'] is a predefined non-attached
      action with special behaviour: it has no parameter at all, even
      non-attached parameters.  Use it if you want to make a link to
      the current page without non-attached parameters.  It is almost
      equivalent to a POST non-attached service without POST
      parameters, on which you register an action that does nothing,
      but you can use it with <a> links, not only forms.  It does not
      keep non attached GET parameters.  *)
  val void_coservice' :
    (unit, unit, get, non_att, co, non_ext, non_reg,
     [ `WithoutSuffix ], unit, unit, _ non_ocaml)
      service

  (** Same as {!void_coservice'} but forcing https. *)
  val https_void_coservice' :
    (unit, unit, get, non_att, co, non_ext, non_reg,
     [ `WithoutSuffix ], unit, unit, _ non_ocaml)
      service

  (** Same as {!void_coservice'} but keeps non attached GET
      parameters. *)
  val void_hidden_coservice' :
    (unit, unit, get, non_att, co, non_ext, non_reg,
     [ `WithoutSuffix ], unit, unit, _ non_ocaml)
      service

  (** Same as {!void_hidden_coservice'} but forcing https. *)
  val https_void_hidden_coservice' :
    (unit, unit, get, non_att, co, non_ext, non_reg,
     [ `WithoutSuffix ], unit, unit, _ non_ocaml)
      service

  (** {3 Static files} *)

  (** The predefined service [static_dir] allows one to create links
      to static files. This service takes the name of a static file as
      a parameter (a string list, slash separated). The actual
      directory in filesystem where static pages will be found must be
      set up in the configuration file with the staticmod
      extension. *)
  val static_dir :
    unit ->
    (string list, unit, get, att, non_co, non_ext, non_reg,
     [ `WithSuffix ], [ `One of string list ] Eliom_parameter.param_name,
     unit, http non_ocaml)
      service

  (** Same as {!static_dir} but forcing https link. *)
  val https_static_dir :
    unit ->
    (string list, unit, get, att, non_co, non_ext, non_reg,
     [ `WithSuffix ], [ `One of string list ] Eliom_parameter.param_name,
     unit, http non_ocaml)
      service

  (** Like [static_dir], but allows one to put GET parameters *)
  val static_dir_with_params :
    ?keep_nl_params:[ `All | `Persistent | `None ] ->
    get_params:('a, [`WithoutSuffix], 'an) Eliom_parameter.params_type ->
    unit ->
    ((string list * 'a), unit, get, att, non_co, non_ext, non_reg,
     [ `WithSuffix ],
     [ `One of string list ] Eliom_parameter.param_name *'an,
     unit, http non_ocaml)
      service

  (** Same as {!static_dir_with_params} but forcing https link. *)
  val https_static_dir_with_params :
    ?keep_nl_params:[ `All | `Persistent | `None ] ->
    get_params:('a, [`WithoutSuffix], 'an) Eliom_parameter.params_type ->
    unit ->
    ((string list * 'a), unit, get, att, non_co, non_ext, non_reg,
     [ `WithSuffix ],
     [ `One of string list ] Eliom_parameter.param_name *'an,
     unit, http non_ocaml)
      service

  (** {2 Miscellaneous} *)

  (** The function [preapply ~service paramaters] creates a new
      service by preapplying [service] to the GET [parameters]. It is
      not possible to register a handler on an preapplied service ;
      preapplied services may be used in links or as fallbacks for
      coservices *)
  val preapply :
    service:
      ('a, 'b, 'meth, att, 'co, 'ext, 'reg, _, 'e, 'f, 'return)
      service ->
    'a ->
    (unit, 'b, 'meth, att, 'co, 'ext, non_reg,
     [ `WithoutSuffix ], unit, 'f, 'return) service

  (** [attach_coservice' ~fallback ~service] attaches the non-attached
      coservice [service] on the URL of [fallback]. This allows to
      create a link to a non-attached coservice but with another URL
      than the current one. It is not possible to register something
      on the service returned by this function. *)
  val attach_coservice' :
    fallback:
      (unit, unit, get, att, _, non_ext, 'rg1,
       _, unit, unit, 'return1) service ->
    service:
      ('get, 'post, 'meth, non_att, co, non_ext, 'rg2,
       [< `WithoutSuffix] as 'sf, 'gn, 'pn, 'return) service ->
    ('get, 'post, 'meth, att, co, non_ext, non_reg,
     'sf, 'gn, 'pn, 'return) service

  (** The function [add_non_localized_get_parameters ~params ~service]
      Adds non localized GET parameters [params] to [service]. See the
      Eliom manual for more information about {% <<a_manual
      chapter="server-params" fragment="nonlocalizedparameters"|non
      localized parameters>>%}. *)
  val add_non_localized_get_parameters :
    params:
      ('p, [ `WithoutSuffix ], 'pn)
      Eliom_parameter.non_localized_params ->
    service:
      ('a, 'b, 'meth, 'attach, 'co, 'ext, 'reg,
       'd, 'e, 'f, 'return)
      service ->
    ('a * 'p, 'b, 'meth, 'attach, 'co, 'ext, 'reg,
     'd, 'e * 'pn, 'f, 'return) service

  (** Same as {!add_non_localized_get_parameters} but with POST
      parameters.*)
  val add_non_localized_post_parameters :
    params:
      ('p, [ `WithoutSuffix ], 'pn)
      Eliom_parameter.non_localized_params ->
    service:
      ('a, 'b, 'meth, 'attach, 'co, 'ext, 'g,
       'd, 'e, 'f, 'return) service ->
    ('a, 'b * 'p, 'meth, 'attach, 'co, 'ext, 'g,
     'd, 'e, 'f * 'pn, 'return) service

  (**/**)

  val which_meth :
    (_, _, 'm, _, _, _, _, _, _, _, _) service -> 'm which_meth

  val get_info :
    (_, _, _, 'att, _, _, _, _, _, _, _) service ->
    'att attached_info

  val is_external : (_, _, _, _, _, _, _, _, _, _, _) service -> bool

  val get_get_params_type_ :
    ('a, _, _, _, _, _, _, 'b, 'c,  _, _) service ->
    ('a, 'b, 'c) Eliom_parameter.params_type

  val get_post_params_type_ :
    (_, 'a, _, _, _, _, _, _, _, 'b, _) service ->
    ('a, [ `WithoutSuffix ], 'b) Eliom_parameter.params_type

  val get_sub_path_ : att -> Eliom_lib.Url.path

  val get_full_path_ : att -> Eliom_lib.Url.path

  val get_prefix_ :   att -> string

  val get_get_name_ : att -> Eliom_common.att_key_serv

  val get_post_name_ : att -> Eliom_common.att_key_serv

  val get_redirect_suffix_ : att -> bool

  val get_na_name_ : non_att -> Eliom_common.na_key_serv

  val get_na_keep_get_na_params_: non_att -> bool

  val get_max_use_ :
    (_, _, _, _, _, _, _, _, _, _, _) service -> int option

  val get_timeout_ :
    (_, _, _, _, _, _, _, _, _, _, _) service -> float option

  val get_https :
    (_, _, _, _, _, _, _, _, _, _, _) service -> bool

  val get_priority_ : att -> int

  val get_client_fun_ :
    ('a, 'b, _, _, _, _, _, _, _, _, _) service ->
    (unit -> ('a -> 'b -> unit Lwt.t) option)
      Eliom_client_value.t

  val has_client_fun_ :
    (_, _, _, _, _, _, _, _, _, _, _) service -> bool

  val has_client_fun_lazy :
    (_, _, _, _, _, _, _, _, _, _, _) service ->
    (unit -> bool) Eliom_client_value.t

  val keep_nl_params :
    (_, _, _, _, _, _, _, _, _, _, _) service ->
    [ `All | `Persistent | `None ]

  val change_get_num :
    ('a, 'b, 'meth, att, 'co, 'ext, 'rg0, 'd, 'e, 'f, 'return) service ->
    att ->
    Eliom_common.att_key_serv ->
    ('a, 'b, 'meth, att, 'co, 'ext, 'rg1, 'd, 'e, 'f, 'return) service

  (* Not implemented on client side: TODO should not be called in
     Eliom_uri *)
  val register_delayed_get_or_na_coservice :
    sp:Eliom_common.server_params ->
    (int * [< Eliom_common.user_scope ] * bool option) ->
    string

  val register_delayed_post_coservice :
    sp:Eliom_common.server_params ->
    (int * [< Eliom_common.user_scope ] * bool option) ->
    Eliom_common.att_key_serv -> string

  (** Whether the service is capable to send application content or
      not. (application content has type
      Eliom_service.eliom_appl_answer: content of the application
      container, or xhr redirection ...).  A link towards a service
      with send_appl_content = XNever will always answer a regular
      http frame (this will stop the application if used in a regular
      link or form, but not with XHR).  XAlways means "for all
      applications" (like redirections/actions).  XSame_appl means
      "only for this application".  If there is a client side
      application, and the service has XAlways or XSame_appl when it
      is the same application, then the link (or form or change_page)
      will expect application content.  *)
  type send_appl_content =
    | XNever
    | XAlways
    | XSame_appl of string * string option
  (* used by eliommod_mkform *)

  (** Returns the name of the application to which belongs the
      service, if any. *)
  val get_send_appl_content :
    (_, _, _, _, _, _, _, _, _, _, _) service -> send_appl_content

  val xhr_with_cookies :
    (_, _, _, _, _, _, _, _, _, _, _) service -> string option option

  val set_client_fun_ :
    ?app:string ->
    service:('a, 'b, _, _, _, _, _, _, _, _, _) service ->
    ('a -> 'b -> unit Lwt.t) Eliom_client_value.t ->
    unit

  val internal_set_client_fun_ :
    service :
      ('a, 'b, _, _, _, _, _, _, _, _, _) service ->
    (unit -> ('a -> 'b -> unit Lwt.t) option) Eliom_client_value.t ->
    unit

end
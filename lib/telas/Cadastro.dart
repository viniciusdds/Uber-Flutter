import 'package:flutter/material.dart';
import 'package:uber/Rotas.dart';
import 'package:uber/model/Usuario.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class Cadastro extends StatefulWidget {
  @override
  _CadastroState createState() => _CadastroState();
}

class _CadastroState extends State<Cadastro> {

  TextEditingController _controllerNome = TextEditingController(text: "Vinicius Damasceno");
  TextEditingController _controllerEmail = TextEditingController(text: "vinicius@email.com");
  TextEditingController _controllerSenha = TextEditingController(text: "1234567");
  bool _tipoUsuario = false;
  String _mensagemErro = "";

  _validarCampos(){

    //Recuperar dados dos campos
    String nome = _controllerNome.text;
    String email = _controllerEmail.text;
    String senha = _controllerSenha.text;

    //validar campos
    if(nome.isNotEmpty){

        if(email.isNotEmpty && email.contains("@")){

          if(senha.isNotEmpty && senha.length > 6){

            Usuario usuario = Usuario();
            usuario.nome = nome;
            usuario.email = email;
            usuario.senha = senha;
            usuario.tipoUsuario = usuario.verificaTipoUsuario(_tipoUsuario);

            _cadastrarUsuario(usuario);

          }else{
             setState(() {
               _mensagemErro = "Preencha a senha! digite mais de 6 caracteres";
             });
          }

        }else{
          setState(() {
            _mensagemErro = "Preencha o E-mail válido";
          });
        }

    }else{
        setState(() {
           _mensagemErro = "Preencha o Nome";
        });
    }
  }

  _cadastrarUsuario(Usuario usuario){

    FirebaseAuth auth = FirebaseAuth.instance;
    FirebaseFirestore db = FirebaseFirestore.instance;

    auth.createUserWithEmailAndPassword(
        email: usuario.email,
        password: usuario.senha
    ).then((firebaseUser) {
      db.collection("usuarios")
          .doc(firebaseUser.user.uid).set(usuario.toMap());

      //redirecionar para o painel, de acordo com o tipoUsuario
      switch(usuario.tipoUsuario){
        case "motorista":
          Navigator.pushNamedAndRemoveUntil(
              context,
              Rotas.ROTA_PAINEL_MOTOR,
              (_) => false
          );
        break;
        case "passageiro":
          Navigator.pushNamedAndRemoveUntil(
              context,
              Rotas.ROTA_PAINEL_PASSAG,
                  (_) => false
          );
        break;
      }

    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Cadastro"),
      ),
      body: Container(
        padding: EdgeInsets.all(16),
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _controllerNome,
                  autofocus: true,
                  keyboardType: TextInputType.text,
                  style: TextStyle(
                      fontSize: 20
                  ),
                  decoration: InputDecoration(
                      contentPadding: EdgeInsets.fromLTRB(32, 16, 32, 16),
                      hintText: "Nome completo",
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6)
                      )
                  ),
                ),
                TextField(
                  controller: _controllerEmail,
                  keyboardType: TextInputType.emailAddress,
                  style: TextStyle(
                      fontSize: 20
                  ),
                  decoration: InputDecoration(
                      contentPadding: EdgeInsets.fromLTRB(32, 16, 32, 16),
                      hintText: "e-mail",
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6)
                      )
                  ),
                ),
                TextField(
                  controller: _controllerSenha,
                  obscureText: true,
                  keyboardType: TextInputType.text,
                  style: TextStyle(
                      fontSize: 20
                  ),
                  decoration: InputDecoration(
                      contentPadding: EdgeInsets.fromLTRB(32, 16, 32, 16),
                      hintText: "senha",
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6)
                      )
                  ),
                ),
                Padding(
                  padding: EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      Text("Passageiro"),
                      Switch(
                          value: _tipoUsuario,
                          onChanged: (bool valor){
                             setState(() {
                                _tipoUsuario = valor;
                             });
                          }
                      ),
                      Text("Motorista"),
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsets.only(top: 16, bottom: 10),
                  child: RaisedButton(
                    child: Text(
                      "Cadastrar",
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 20
                      ),
                    ),
                    color: Color(0xff1ebbd8),
                    padding: EdgeInsets.fromLTRB(32, 16, 32, 16),
                    onPressed: (){
                      _validarCampos();
                    },
                  ),
                ),
                Padding(
                  padding: EdgeInsets.only(top: 16),
                  child: Center(
                    child: Text(
                      _mensagemErro,
                      style: TextStyle(color: Colors.red, fontSize: 20),
                    ),
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}
